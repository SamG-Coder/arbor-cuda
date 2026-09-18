// The complete branching scaffold and every leaf have persistent IDs.
// Generation happens once. Camera distance NEVER changes topology or leaf count.
__device__ void storeCurve(float* B,int id,float3 a,float3 b,float3 c,float3 d,float ra,float rb,float arc,int seed){int o=id*CS;write3(B,o,a);write3(B,o+3,b);write3(B,o+6,c);write3(B,o+9,d);B[o+12]=ra;B[o+13]=rb;B[o+14]=arc;B[o+15]=(float)seed;B[o+16]=length3(d-a);}
__global__ void growTree(float* B,int level,int seed){
 int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);
 if(level==0){
  if(i==0)storeCurve(B,0,make_float3(0.0f,-0.15f,0.0f),make_float3(-0.22f,1.1f,0.16f),make_float3(0.23f,2.9f,-0.19f),make_float3(0.04f,4.2f,0.05f),0.68f,0.23f,0.0f,seed);
  if(i<8){float a=(float)i*PI*0.25f+(rnd(i,seed)-0.5f)*0.5f;float3 d=make_float3(cosf(a),0.0f,sinf(a));float len=2.0f+rnd(i+10,seed)*1.4f;float3 p=d*0.32f+make_float3(0.0f,0.27f,0.0f);storeCurve(B,i+1,p,d*0.8f+make_float3(0.0f,0.10f,0.0f),d*(len*0.68f)+make_float3(0.0f,-0.06f,0.0f),d*len+make_float3(0.0f,-0.16f,0.0f),0.235f,0.012f,0.0f,seed+i*37);}
  return;
 }
 if(level==1&&i<12){
  float t=0.31f+0.65f*(float)i/11.0f;float a=(float)i*2.399963f+0.31f;float r=rnd(i+37,seed);float len=3.2f+2.1f*r;
  float3 base=curveAt(B,0,t);float3 d=make_float3(cosf(a),0.0f,sinf(a));float3 side=make_float3(-d.z,0.0f,d.x);
  float3 end=base+d*(len*(0.87f-0.30f*t))+make_float3(0.0f,len*(0.60f+0.40f*t),0.0f)+side*((r-0.5f)*1.2f);
  float ra=curveRadius(B,0,t)*(0.46f+0.13f*r);
  storeCurve(B,9+i,base,base+d*(len*0.29f)+make_float3(0.0f,len*0.12f,0.0f),end-d*(len*0.17f)-make_float3(0.0f,len*0.26f,0.0f),end,ra,ra*0.14f,B[14]+t*4.2f,seed+i*19);return;
 }
 int count=level==2?72:(level==3?288:1728);if(i>=count)return;
 int children=level==2?6:(level==3?4:6);int offset=level==2?21:(level==3?93:381);int parentOffset=level==2?9:(level==3?21:93);
 int parent=parentOffset+i/children;int child=i%children;float h=rnd(i+level*730,seed);
 float t=0.23f+0.72f*((float)child+0.35f)/(float)children;
 float3 p=curveAt(B,parent,t);float3 tangent=curveTangent(B,parent,t);float3 u=basisU(tangent);float3 v=cross3(tangent,u);
 float angle=(float)child*2.399963f+h*0.8f;float3 lateral=u*cosf(angle)+v*sinf(angle);
 float3 d=norm3(tangent*0.52f+lateral*(level==4?0.64f:0.80f)+make_float3(0.0f,0.26f,0.0f));
 float len=level==2?1.65f+1.10f*h:(level==3?0.85f+0.65f*h:0.43f+0.37f*h);
 len*=0.84f+0.25f*(1.0f-t);
 float3 end=p+d*len+make_float3(0.0f,len*0.16f,0.0f);
 float radius=curveRadius(B,parent,t)*(level==4?0.30f:0.40f);radius=fmaxf(level==4?0.0035f:0.008f,radius);
 storeCurve(B,offset+i,p,p+tangent*(len*0.25f)+lateral*(len*0.11f),end-d*(len*0.28f)+make_float3(0.0f,len*0.05f,0.0f),end,radius,radius*(level==4?0.30f:0.22f),B[parent*CS+14]+t*B[parent*CS+16],seed+(offset+i)*31);
}
__global__ void makePrimitives(const float* B,float* P,int seed){
 int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=CAPACITY)return;int b=i*PS;for(int j=0;j<PS;j++)P[b+j]=0.0f;P[b+3]=-1.0f;if(i>=OBJECT_COUNT)return;
 if(i<WOOD_COUNT){
  int c=0;int segment=0;int segments=12;
  if(i<12){c=0;segment=i;segments=12;}
  else if(i<60){c=1+(i-12)/6;segment=(i-12)%6;segments=6;}
  else if(i<156){c=9+(i-60)/8;segment=(i-60)%8;segments=8;}
  else if(i<516){c=21+(i-156)/5;segment=(i-156)%5;segments=5;}
  else if(i<1668){c=93+(i-516)/4;segment=(i-516)%4;segments=4;}
  else{c=381+(i-1668)/2;segment=(i-1668)%2;segments=2;}
  float t0=(float)segment/(float)segments;float t1=(float)(segment+1)/(float)segments;
  write3(P,b,curveAt(B,c,t0));P[b+3]=0.0f;write3(P,b+4,curveAt(B,c,t1));P[b+7]=curveRadius(B,c,t0);P[b+11]=curveRadius(B,c,t1);
  P[b+15]=B[c*CS+15];float arclength=B[c*CS+14];
  for(int j=0;j<12;j++)if(j<segment)arclength+=length3(curveAt(B,c,(float)(j+1)/(float)segments)-curveAt(B,c,(float)j/(float)segments));
  P[b+16]=arclength;P[b+17]=(float)c;P[b+18]=B[c*CS+12];write3(P,b+8,basisU(curveTangent(B,c,0.0f)));return;
 }
 if(i<WOOD_COUNT+LEAF_COUNT){
  int leaf=i-WOOD_COUNT;int twig=leaf/14;int k=leaf%14;int c=381+twig;float h=rnd(leaf+13,seed);float t=0.16f+0.81f*((float)k+0.4f)/14.0f;
  float3 anchor=curveAt(B,c,t);float3 axis=curveTangent(B,c,t);float3 bu=basisU(axis);float3 bv=cross3(axis,bu);float angle=(float)k*2.399963f+rnd(twig,seed)*6.28f;
  float3 out=norm3(bu*cosf(angle)+bv*sinf(angle));float3 u=norm3(out*0.82f+axis*0.35f+make_float3(0.0f,0.20f,0.0f));
  float3 normal=norm3(make_float3(0.0f,1.0f,0.0f)+out*(0.20f+h*0.38f));float3 v=norm3(cross3(normal,u));normal=norm3(cross3(u,v));
  // A short petiole is part of this ray-intersected object, not a texture.
  write3(P,b,anchor);P[b+3]=1.0f;write3(P,b+4,u);P[b+7]=0.145f+0.075f*h;
  write3(P,b+8,v);P[b+11]=P[b+7]*(0.34f+0.07f*rnd(leaf+37,seed));write3(P,b+12,normal);P[b+15]=(float)(leaf+seed*11);
  P[b+16]=0.023f+0.024f*rnd(leaf+149,seed);P[b+17]=0.013f+0.016f*h;P[b+18]=(rnd(leaf+777,seed)-0.5f)*0.10f;P[b+19]=(float)twig;return;
 }
 int rock=i-WOOD_COUNT-LEAF_COUNT;float a=rnd(rock*3+1,seed)*6.2831853f;float r=0.8f+4.5f*sqrtf(rnd(rock*3+2,seed));float size=0.045f+0.19f*powf(rnd(rock+371,seed),3.0f);
 write3(P,b,make_float3(cosf(a)*r,size*0.30f-0.015f,sinf(a)*r));P[b+3]=2.0f;write3(P,b+4,make_float3(size,size*0.55f,size*(0.7f+rnd(rock+16,seed)*0.5f)));P[b+15]=(float)(rock+seed);
}
__device__ float3 boundLow(const float* P,int id){int b=id*PS;int type=(int)P[b+3];if(type<0)return make_float3(FAR,FAR,FAR);float3 a=read3(P,b);if(type==0){float r=fmaxf(P[b+7],P[b+11])+0.002f;return min3(a,read3(P,b+4))-make_float3(r,r,r);}if(type==2)return a-read3(P,b+4);float radius=P[b+7]+P[b+16]+0.025f;return a-make_float3(radius,radius,radius);}
__device__ float3 boundHigh(const float* P,int id){int b=id*PS;int type=(int)P[b+3];if(type<0)return make_float3(-FAR,-FAR,-FAR);float3 a=read3(P,b);if(type==0){float r=fmaxf(P[b+7],P[b+11])+0.002f;return max3(a,read3(P,b+4))+make_float3(r,r,r);}if(type==2)return a+read3(P,b+4);float radius=P[b+7]+P[b+16]+0.025f;return a+make_float3(radius,radius,radius);}
