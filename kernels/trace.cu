__device__ float sphereT(float3 ro,float3 rd,float3 p,float radius){float3 q=ro-p;float b=dot3(q,rd);float c=dot3(q,q)-radius*radius;float d=b*b-c;if(d<0.0f)return FAR;float t=-b-sqrtf(d);if(t<=0.0001f)t=-b+sqrtf(d);return t>0.0001f?t:FAR;}
// Intersect the union of a tapered segment and its spherical joint caps.
__device__ float tubeT(float3 ro,float3 rd,float3 a,float3 b,float ra,float rb){float3 axis=b-a;float len=length3(axis);axis=axis/fmaxf(len,0.000001f);float3 q=ro-a;float z=dot3(q,axis);float dz=dot3(rd,axis);float k=(rb-ra)/fmaxf(0.000001f,len);float3 v=q-axis*z;float3 d=rd-axis*dz;float radius=ra+k*z;float aa=dot3(d,d)-k*k*dz*dz;float bb=dot3(v,d)-radius*k*dz;float cc=dot3(v,v)-radius*radius;float best=fminf(sphereT(ro,rd,a,ra),sphereT(ro,rd,b,rb));float disc=bb*bb-aa*cc;
 if(disc>=0.0f&&fabsf(aa)>0.0000001f){for(int j=0;j<2;j++){float t=(-bb+(j==0?-1.0f:1.0f)*sqrtf(disc))/aa;float h=z+t*dz;if(t>0.0001f&&h>=0.0f&&h<=len)best=fminf(best,t);}}
 return best;
}
__device__ float woodT(const float* P,int id,float3 ro,float3 rd,float footprint,bool refine){int b=id*PS;float3 a=read3(P,b);float3 end=read3(P,b+4);
 if(!refine){float ra=P[b+7]-fminf(0.021f,P[b+7]*0.055f)*0.32f;float rb=P[b+11]-fminf(0.021f,P[b+11]*0.055f)*0.32f;return tubeT(ro,rd,a,end,ra,rb);}
 // Primary rays always use the same field solver: no solver/geometry swap
 // when a detail band fades to zero. Shadow rays use mean-radius wood.

 float t=tubeT(ro,rd,a,end,P[b+7],P[b+11]);if(t>=FAR)return FAR;
 float2 span=boxSpan(ro,rd,boundLow(P,id),boundHigh(P,id));float eps=fmaxf(0.000025f,fminf(0.00025f,footprint*0.13f));
 for(int k=0;k<64;k++){float f=woodField(P,id,ro+rd*t,footprint);if(f<eps)return t;t+=fmaxf(eps*0.35f,f*0.27f);if(t>span.y)return FAR;}
 // Bounded solver: discard unresolved grazing intersections, never paint a box.
 return FAR;
}
__device__ float leafT(const float* P,int id,float3 ro,float3 rd,float footprint,float time,float wind){int b=id*PS;float3 origin=read3(P,b);float3 u=leafU(P,id,time,wind);float3 v=read3(P,b+8);float3 n=leafN(P,id,time,wind);float stem=P[b+16];float len=P[b+7];float width=P[b+11];float3 q=ro-origin;float x=dot3(q,u)-stem;float y=dot3(q,v);float z=dot3(q,n);float dx=dot3(rd,u);float dy=dot3(rd,v);float dz=dot3(rd,n);
 float best=tubeT(ro,rd,origin,origin+u*stem,0.0011f,0.00065f);
 float2 span=boxSpan(make_float3(x,y,z),make_float3(dx,dy,dz),make_float3(-0.001f,-width,-0.035f),make_float3(len+0.001f,width,0.065f));
 if(span.y<fmaxf(0.0001f,span.x))return best;
 // Newton solves the same curved leaf at every distance; broad lobes/camber
 // are permanent. Only subpixel serrations and midrib relief are filtered.
 float t=fabsf(dz)>0.000001f?-z/dz:(span.x+span.y)*0.5f;t=clampf(t,fmaxf(0.0001f,span.x),span.y);
 for(int k=0;k<7;k++){
  float xx=x+dx*t;float yy=y+dy*t;float height=leafHeight(xx,yy,len,width,P[b+17],P[b+18],footprint);float f=z+dz*t-height;
  float e=0.00015f;float hx=(leafHeight(xx+e,yy,len,width,P[b+17],P[b+18],footprint)-leafHeight(xx-e,yy,len,width,P[b+17],P[b+18],footprint))/(2.0f*e);float hy=(leafHeight(xx,yy+e,len,width,P[b+17],P[b+18],footprint)-leafHeight(xx,yy-e,len,width,P[b+17],P[b+18],footprint))/(2.0f*e);
  float deriv=dz-hx*dx-hy*dy;if(fabsf(deriv)<0.00001f)break;t-=clampf(f/deriv,-0.13f,0.13f);t=clampf(t,span.x,span.y);
 }
 float xx=x+dx*t;float yy=y+dy*t;float err=fabsf(z+dz*t-leafHeight(xx,yy,len,width,P[b+17],P[b+18],footprint));
 if(t>0.0001f&&xx>0.0f&&xx<len&&fabsf(yy)<leafWidth(xx,len,width,footprint)&&err<0.0003f)best=fminf(best,t);
 return best;
}
__device__ float objectT(const float* P,int id,float3 ro,float3 rd,float footprint,float time,float wind,bool refine){int b=id*PS;int type=(int)P[b+3];if(type<0)return FAR;if(type==0)return woodT(P,id,ro,rd,footprint,refine);if(type==1)return leafT(P,id,ro,rd,footprint,time,wind);float3 h=read3(P,b+4);float3 q=ro-read3(P,b);float3 p=make_float3(q.x/h.x,q.y/h.y,q.z/h.z);float3 d=make_float3(rd.x/h.x,rd.y/h.y,rd.z/h.z);float aa=dot3(d,d);float bb=dot3(p,d);float cc=dot3(p,p)-1.0f;float disc=bb*bb-aa*cc;if(disc<0.0f)return FAR;float t=(-bb-sqrtf(disc))/aa;return t>0.0001f?t:FAR;}
__device__ float2 traceTree(const float* P,const float* Nodes,const unsigned int* Order,float3 ro,float3 rd,float cone,float time,float wind,float best,int ignore,bool shadows){
 int stack[32];int top=0;int node=1;int found=-1;
 for(int visit=0;visit<NODE_COUNT;visit++){
  if(node<=0)break;int b=node*8;float2 span=boxSpan(ro,rd,read3(Nodes,b),read3(Nodes,b+4));bool hit=Nodes[b+3]>0.0f&&span.y>=fmaxf(0.0001f,span.x)&&span.x<best;
  if(hit&&node<CAPACITY){int left=node*2;int right=left+1;int lb=left*8;int rb=right*8;float2 ls=boxSpan(ro,rd,read3(Nodes,lb),read3(Nodes,lb+4));float2 rs=boxSpan(ro,rd,read3(Nodes,rb),read3(Nodes,rb+4));bool lh=Nodes[lb+3]>0.0f&&ls.y>=fmaxf(0.0001f,ls.x)&&ls.x<best;bool rh=Nodes[rb+3]>0.0f&&rs.y>=fmaxf(0.0001f,rs.x)&&rs.x<best;
   if(lh&&rh){bool l=ls.x<rs.x;stack[top]=l?right:left;top++;node=l?left:right;continue;}if(lh){node=left;continue;}if(rh){node=right;continue;}
  }else if(hit){int id=(int)Order[node-CAPACITY];if(id!=ignore){float footprint=fmaxf(0.000005f,cone*fmaxf(0.05f,span.x));float t=objectT(P,id,ro,rd,footprint,time,wind,!shadows);if(t<best){best=t;found=id;}}}
  node=0;if(top>0){top--;node=stack[top];}
 }
 return make_float2(best,(float)found);
}
__device__ float3 objectNormal(const float* P,int id,float3 p,float footprint,float time,float wind){int b=id*PS;int type=(int)P[b+3];if(type==0){float e=fmaxf(0.000035f,fminf(0.0005f,footprint*0.18f));float3 dx=make_float3(e,0.0f,0.0f);float3 dy=make_float3(0.0f,e,0.0f);float3 dz=make_float3(0.0f,0.0f,e);return norm3(make_float3(woodField(P,id,p+dx,footprint)-woodField(P,id,p-dx,footprint),woodField(P,id,p+dy,footprint)-woodField(P,id,p-dy,footprint),woodField(P,id,p+dz,footprint)-woodField(P,id,p-dz,footprint)));}
 if(type==1){float3 u=leafU(P,id,time,wind);float3 v=read3(P,b+8);float3 n=leafN(P,id,time,wind);float3 q=p-read3(P,b);float x=dot3(q,u)-P[b+16];float y=dot3(q,v);if(x<0.0f){float3 centre=read3(P,b)+u*(x+P[b+16]);return norm3(p-centre);}float e=0.0002f;float a=(leafHeight(x+e,y,P[b+7],P[b+11],P[b+17],P[b+18],footprint)-leafHeight(x-e,y,P[b+7],P[b+11],P[b+17],P[b+18],footprint))/(2.0f*e);float c=(leafHeight(x,y+e,P[b+7],P[b+11],P[b+17],P[b+18],footprint)-leafHeight(x,y-e,P[b+7],P[b+11],P[b+17],P[b+18],footprint))/(2.0f*e);return norm3(n-u*a-v*c);}
 float3 q=p-read3(P,b);float3 h=read3(P,b+4);return norm3(make_float3(q.x/(h.x*h.x),q.y/(h.y*h.y),q.z/(h.z*h.z)));
}
__device__ float2 traceForest(const float* P,const float* Nodes,const unsigned int* Order,float3 ro,float3 rd,float cone,float time,float wind,float best,int worldSeed,int* treeOut,bool shadows){
 int foundTree=-1;float found=-1.0f;float half=(float)FOREST_SIDE*FOREST_SPACING*0.5f;
 // Coarse forest traversal is a 2D DDA. Far-away rays visit only the cells they cross;
 // they do not loop over every tree. Each occupied cell has one independently seeded tree.
 float2 worldSpan=boxSpan(ro,rd,make_float3(-half,-1.2f,-half),make_float3(half,13.5f,half));
 float enter=fmaxf(0.0f,worldSpan.x);float exit=fminf(best,worldSpan.y);if(exit<enter){*treeOut=-1;return make_float2(best,-1.0f);}
 float3 pos=ro+rd*(enter+0.0002f);int ix=(int)floorf(pos.x/FOREST_SPACING+(float)FOREST_SIDE*0.5f+0.5f);int iz=(int)floorf(pos.z/FOREST_SPACING+(float)FOREST_SIDE*0.5f+0.5f);
 int sx=rd.x>=0.0f?1:-1;int sz=rd.z>=0.0f?1:-1;float invx=invSafe(rd.x);float invz=invSafe(rd.z);
 float bx=((float)(ix-FOREST_SIDE/2)+(sx>0?0.5f:-0.5f))*FOREST_SPACING;float bz=((float)(iz-FOREST_SIDE/2)+(sz>0?0.5f:-0.5f))*FOREST_SPACING;
 float tx=(bx-ro.x)*invx;float tz=(bz-ro.z)*invz;float dx=FOREST_SPACING*fabsf(invx);float dz=FOREST_SPACING*fabsf(invz);
 for(int step=0;step<48;step++){
  if(ix<0||iz<0||ix>=FOREST_SIDE||iz>=FOREST_SIDE)break;int tree=iz*FOREST_SIDE+ix;float sc=forestScale(tree,worldSeed);float3 centre=forestPos(tree,worldSeed)+make_float3(0.0f,4.4f*sc,0.0f);float radius=6.6f*sc;float broad=sphereT(ro,rd,centre,radius);
  if(broad<best){float3 lr=forestToLocalPoint(ro,tree,worldSeed);float3 ld=forestToLocalDir(rd,tree,worldSeed);float phase=(float)(forestSeed(tree,worldSeed)&8191)*0.0017f;float2 h=traceTree(P,Nodes,Order,lr,ld,cone/sc,time+phase,wind,best/sc,-1,shadows);if(h.y>=0.0f&&h.x*sc<best){best=h.x*sc;found=h.y;foundTree=tree;}}
  float next=tx<tz?tx:tz;if(next>exit||next>best)break;if(tx<tz){ix+=sx;tx+=dx;}else{iz+=sz;tz+=dz;}
 }
 *treeOut=foundTree;return make_float2(best,found);
}
__global__ void tracePixels(const float* P,const float* Nodes,const unsigned int* Order,const float* C,float* Hit,int width,int height){int x=(int)(blockIdx.x*blockDim.x+threadIdx.x);int y=(int)(blockIdx.y*blockDim.y+threadIdx.y);if(x>=width||y>=height)return;int b=(y*width+x)*4;float3 ro=cameraPos(C);float3 rd=cameraRay(C,x,y,width,height);float ground=rd.y<-0.00001f?-ro.y/rd.y:FAR;int tree=-1;float2 h=traceForest(P,Nodes,Order,ro,rd,C[14]/(float)height,C[8],C[11],ground>0.0f?ground:FAR,(int)C[31],&tree,false);Hit[b]=h.x;Hit[b+1]=h.y;Hit[b+2]=(float)tree;Hit[b+3]=C[14]*h.x/(float)height;}
