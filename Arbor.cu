// ARBOR: combined source, generated from kernels/*.cu.

// === COMMON ===
// ARBOR / CUDA-authored specimen renderer. Metres throughout.
#define PI 3.14159265359f
#define FAR 100000.0f
#define CAPACITY 32768
#define NODE_COUNT 65536
#define PS 24
#define CS 20
#define CURVES 2109
#define WOOD_COUNT 5124
#define LEAF_COUNT 24192
#define ROCK_COUNT 96
#define OBJECT_COUNT 29412

__device__ float clampf(float x,float a,float b){return fminf(b,fmaxf(a,x));}
__device__ float sat(float x){return clampf(x,0.0f,1.0f);}
__device__ float lerp(float a,float b,float t){return a+(b-a)*t;}
__device__ float frac(float a){return a-floorf(a);}
__device__ float smooth(float a,float b,float x){float t=sat((x-a)/(b-a));return t*t*(3.0f-2.0f*t);}
__device__ float dot3(float3 a,float3 b){return a.x*b.x+a.y*b.y+a.z*b.z;}
__device__ float3 cross3(float3 a,float3 b){return make_float3(a.y*b.z-a.z*b.y,a.z*b.x-a.x*b.z,a.x*b.y-a.y*b.x);}
__device__ float length3(float3 a){return sqrtf(dot3(a,a));}
__device__ float3 norm3(float3 a){return a/fmaxf(0.0000001f,length3(a));}
__device__ float3 min3(float3 a,float3 b){return make_float3(fminf(a.x,b.x),fminf(a.y,b.y),fminf(a.z,b.z));}
__device__ float3 max3(float3 a,float3 b){return make_float3(fmaxf(a.x,b.x),fmaxf(a.y,b.y),fmaxf(a.z,b.z));}
__device__ float3 abs3(float3 a){return make_float3(fabsf(a.x),fabsf(a.y),fabsf(a.z));}
__device__ float3 mix3(float3 a,float3 b,float t){return a+(b-a)*t;}
__device__ float3 read3(const float* a,int i){return make_float3(a[i],a[i+1],a[i+2]);}
__device__ void write3(float* a,int i,float3 v){a[i]=v.x;a[i+1]=v.y;a[i+2]=v.z;}
__device__ unsigned int hashU(unsigned int x){x^=x>>16;x*=2146121005u;x^=x>>15;x*=2221713035u;x^=x>>16;return x;}
__device__ float rnd(int n,int seed){return (float)(hashU((unsigned int)n^hashU((unsigned int)seed))&16777215u)/16777216.0f;}
__device__ float hash2(int x,int y,int seed){return rnd(x*1973+y*9277,seed);}
__device__ float noise(float x,float y,int seed){int ix=(int)floorf(x);int iy=(int)floorf(y);float fx=frac(x);float fy=frac(y);fx=fx*fx*(3.0f-2.0f*fx);fy=fy*fy*(3.0f-2.0f*fy);return lerp(lerp(hash2(ix,iy,seed),hash2(ix+1,iy,seed),fx),lerp(hash2(ix,iy+1,seed),hash2(ix+1,iy+1,seed),fx),fy);}
__device__ float noise3(float3 p,int seed){int iz=(int)floorf(p.z);float f=frac(p.z);f=f*f*(3.0f-2.0f*f);return lerp(noise(p.x,p.y,seed+iz*131),noise(p.x,p.y,seed+(iz+1)*131),f);}
__device__ float invSafe(float x){return fabsf(x)<0.00000001f?(x<0.0f?-100000000.0f:100000000.0f):1.0f/x;}
__device__ float2 boxSpan(float3 ro,float3 rd,float3 lo,float3 hi){float3 a=(lo-ro)*make_float3(invSafe(rd.x),invSafe(rd.y),invSafe(rd.z));float3 b=(hi-ro)*make_float3(invSafe(rd.x),invSafe(rd.y),invSafe(rd.z));float3 mn=min3(a,b);float3 mx=max3(a,b);return make_float2(fmaxf(mn.x,fmaxf(mn.y,mn.z)),fminf(mx.x,fminf(mx.y,mx.z)));}
__device__ float3 basisU(float3 n){return norm3(cross3(fabsf(n.y)<0.91f?make_float3(0.0f,1.0f,0.0f):make_float3(0.0f,0.0f,1.0f),n));}
__device__ float3 curveAt(const float* B,int id,float t){int b=id*CS;float q=1.0f-t;return read3(B,b)*(q*q*q)+read3(B,b+3)*(3.0f*q*q*t)+read3(B,b+6)*(3.0f*q*t*t)+read3(B,b+9)*(t*t*t);}
__device__ float3 curveTangent(const float* B,int id,float t){int b=id*CS;float q=1.0f-t;return norm3((read3(B,b+3)-read3(B,b))*(q*q)+(read3(B,b+6)-read3(B,b+3))*(2.0f*q*t)+(read3(B,b+9)-read3(B,b+6))*(t*t));}
__device__ float curveRadius(const float* B,int id,float t){return lerp(B[id*CS+12],B[id*CS+13],t);}
// C1-continuous band weight. The footprint is metres per pixel, not a LOD index.
__device__ float bandWeight(float period,float footprint){return 1.0f-smooth(period*0.12f,period*0.65f,footprint);}
__device__ float3 cameraPos(const float* C){return read3(C,0);}
__device__ float3 forwardC(const float* C){return norm3(read3(C,4)-read3(C,0));}
__device__ float3 rightC(const float* C){return norm3(cross3(forwardC(C),make_float3(0.0f,1.0f,0.0f)));}
__device__ float3 sunC(const float* C){return norm3(make_float3(cosf(C[12])*cosf(C[13]),sinf(C[13]),sinf(C[12])*cosf(C[13])));}
__device__ unsigned int packRGB(float3 c){unsigned int r=(unsigned int)(sat(c.x)*255.0f+0.5f);unsigned int g=(unsigned int)(sat(c.y)*255.0f+0.5f);unsigned int b=(unsigned int)(sat(c.z)*255.0f+0.5f);return r|(g<<8)|(b<<16)|4278190080u;}
__device__ float halton(int n,int base){float f=1.0f;float r=0.0f;for(int j=0;j<12;j++){if(n<=0)break;f/=(float)base;r+=f*(float)(n%base);n/=base;}return r;}
__device__ float3 cameraRay(const float* C,int x,int y,int width,int height){int sample=(int)C[9];float jx=halton(sample+1,2)-0.5f;float jy=halton(sample+1,3)-0.5f;float u=((float)x+0.5f+jx-(float)width*0.5f)/(float)height;float v=((float)height*0.5f-(float)y-0.5f-jy)/(float)height;float3 f=forwardC(C);float3 r=rightC(C);float3 up=cross3(r,f);return norm3(f+r*(u*C[14])+up*(v*C[14]));}

// FOREST instancing. Every cell derives an independent deterministic seed.
#define FOREST_SIDE 18
#define FOREST_COUNT 324
#define FOREST_SPACING 28.0f
__device__ int forestSeed(int tree,int worldSeed){return (int)(hashU((unsigned int)(tree*92821+worldSeed*68917+17))&1048575u);}
__device__ float3 forestPos(int tree,int worldSeed){
 int x=tree%FOREST_SIDE-FOREST_SIDE/2;int z=tree/FOREST_SIDE-FOREST_SIDE/2;int s=forestSeed(tree,worldSeed);
 float jx=(rnd(1,s)-0.5f)*10.0f;float jz=(rnd(2,s)-0.5f)*10.0f;
 float warpX=(noise((float)x*0.19f,(float)z*0.19f,worldSeed+311)-0.5f)*3.0f;
 float warpZ=(noise((float)x*0.19f+17.0f,(float)z*0.19f-9.0f,worldSeed+733)-0.5f)*3.0f;
 return make_float3((float)x*FOREST_SPACING+jx+warpX,0.0f,(float)z*FOREST_SPACING+jz+warpZ);
}
__device__ float forestScale(int tree,int worldSeed){int s=forestSeed(tree,worldSeed);return 0.72f+rnd(3,s)*0.62f;}
__device__ float forestYaw(int tree,int worldSeed){return rnd(4,forestSeed(tree,worldSeed))*PI*2.0f;}
__device__ float3 forestToLocalPoint(float3 p,int tree,int worldSeed){float3 q=p-forestPos(tree,worldSeed);float a=-forestYaw(tree,worldSeed);float c=cosf(a),s=sinf(a);float sc=forestScale(tree,worldSeed);return make_float3(q.x*c-q.z*s,q.y,q.x*s+q.z*c)/sc;}
__device__ float3 forestToLocalDir(float3 d,int tree,int worldSeed){float a=-forestYaw(tree,worldSeed);float c=cosf(a),s=sinf(a);return norm3(make_float3(d.x*c-d.z*s,d.y,d.x*s+d.z*c));}
__device__ float3 forestToWorldNormal(float3 n,int tree,int worldSeed){float a=forestYaw(tree,worldSeed);float c=cosf(a),s=sinf(a);return norm3(make_float3(n.x*c-n.z*s,n.y,n.x*s+n.z*c));}


// === TREE ===
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


// === CACHE ===
// Fixed-capacity BVH. No distance-driven replacement, eviction or topology change.
__device__ unsigned int spread(unsigned int x){x&=1023u;x=(x|(x<<16))&50331903u;x=(x|(x<<8))&50393103u;x=(x|(x<<4))&51130563u;x=(x|(x<<2))&153391689u;return x;}
__global__ void makeKeys(const float* P,unsigned int* Keys,unsigned int* Order){int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=CAPACITY)return;Order[i]=(unsigned int)i;if(P[i*PS+3]<0.0f){Keys[i]=4294967295u;return;}float3 p=(boundLow(P,i)+boundHigh(P,i))*0.5f;unsigned int x=(unsigned int)(sat((p.x+12.0f)/24.0f)*1023.0f);unsigned int y=(unsigned int)(sat((p.y+1.0f)/18.0f)*1023.0f);unsigned int z=(unsigned int)(sat((p.z+12.0f)/24.0f)*1023.0f);Keys[i]=spread(x)|(spread(y)<<1)|(spread(z)<<2);}
__global__ void sortPass(unsigned int* Keys,unsigned int* Order,int distance,int span){int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=CAPACITY)return;int j=i^distance;if(j<=i)return;unsigned int a=Keys[i];unsigned int b=Keys[j];unsigned int ia=Order[i];unsigned int ib=Order[j];bool greater=a>b||(a==b&&ia>ib);bool ascending=(i&span)==0;if(greater==ascending){Keys[i]=b;Keys[j]=a;Order[i]=ib;Order[j]=ia;}}
__global__ void makeBounds(const float* P,const unsigned int* Order,float* Nodes){int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=CAPACITY)return;int id=(int)Order[i];int b=(CAPACITY+i)*8;write3(Nodes,b,boundLow(P,id));write3(Nodes,b+4,boundHigh(P,id));Nodes[b+3]=P[id*PS+3]>=0.0f?1.0f:0.0f;Nodes[b+7]=(float)id;}
__global__ void reduceBounds(float* Nodes,int first){int i=(int)(blockIdx.x*blockDim.x+threadIdx.x);if(i>=first)return;int b=(first+i)*8;int a=b*2;int c=a+8;write3(Nodes,b,min3(read3(Nodes,a),read3(Nodes,c)));write3(Nodes,b+4,max3(read3(Nodes,a+4),read3(Nodes,c+4)));Nodes[b+3]=Nodes[a+3]+Nodes[c+3];Nodes[b+7]=-1.0f;}


// === SURFACE ===
// Bark is a bounded height field; high frequencies converge to their mean as
// the projected footprint grows. No distance thresholds replace the tree.
__device__ float2 woodUV(const float* P,int id,float3 p){int b=id*PS;float3 a=read3(P,b);float3 d=norm3(read3(P,b+4)-a);float3 initial=read3(P,b+8);float3 u=norm3(initial-d*dot3(initial,d));float3 v=cross3(d,u);float3 q=p-a;float z=dot3(q,d);float theta=atan2f(dot3(q,v),dot3(q,u));return make_float2(theta,P[b+16]+z);}
__device__ float barkCut(const float* P,int id,float3 p,float footprint){
 int b=id*PS;float3 a=read3(P,b);float3 d=read3(P,b+4)-a;float along=sat(dot3(p-a,d)/fmaxf(0.000001f,dot3(d,d)));float radius=lerp(P[b+7],P[b+11],along);
 float amp=fminf(0.021f,radius*0.055f);int columns=(int)fmaxf(7.0f,floorf(P[b+18]*2.0f*PI/0.065f+0.5f));float period=radius*2.0f*PI/(float)columns;
 float coarse=bandWeight(period,footprint);float fine=bandWeight(0.010f,footprint);float grain=bandWeight(0.0025f,footprint);
 if(coarse<0.000001f&&fine<0.000001f)return amp*0.32f;
 float2 uv=woodUV(P,id,p);float theta=uv.x;float arc=uv.y;int seed=(int)P[b+15];
 float x=(theta/(2.0f*PI)+0.5f)*(float)columns+0.32f*sinf(arc*6.7f+cosf(theta)*3.0f)+0.15f*sinf(arc*19.0f+sinf(theta)*2.0f);
 float y=arc/0.19f+0.25f*sinf(theta*7.0f)+0.1f*sinf(theta*19.0f);
 int ix=(int)floorf(x);int iy=(int)floorf(y);float first=100.0f;float second=100.0f;
 for(int j=-1;j<=1;j++)for(int k=-1;k<=1;k++){
  int cell=ix+k;int wrapped=((cell%columns)+columns)%columns;
  float xx=(float)cell+0.18f+0.64f*hash2(wrapped,iy+j,seed)-x;
  float yy=(float)(iy+j)+0.18f+0.64f*hash2(wrapped+columns,iy+j,seed+31)-y;
  float dd=xx*xx+yy*yy;if(dd<first){second=first;first=dd;}else if(dd<second)second=dd;
 }
 float gap=sqrtf(second)-sqrtf(first);float fissure=1.0f-smooth(0.015f,0.17f,gap);
 float plates=fissure*fissure;
 float3 coord=make_float3(cosf(theta)*9.0f,sinf(theta)*9.0f,arc*23.0f);
 float splinter=noise3(coord,seed);float pores=noise3(coord*4.0f,seed+731);
 return amp*clampf(0.32f+coarse*(plates-0.37f)*0.69f+fine*(splinter-0.5f)*0.24f+grain*(pores-0.5f)*0.08f,0.005f,1.0f);
}
__device__ float woodField(const float* P,int id,float3 p,float footprint){int b=id*PS;float3 a=read3(P,b);float3 ab=read3(P,b+4)-a;float t=sat(dot3(p-a,ab)/fmaxf(0.0000001f,dot3(ab,ab)));float radius=lerp(P[b+7],P[b+11],t);return length3(p-a-ab*t)-radius+barkCut(P,id,p,footprint);}
__device__ float3 leafU(const float* P,int id,float time,float wind){int b=id*PS;float3 u=read3(P,b+4);float3 n=read3(P,b+12);float phase=(float)(((int)P[b+15])%8192)*0.618f;float a=wind*(0.11f*sinf(time*2.1f+phase)+0.045f*sinf(time*5.8f+phase*1.7f));return u*cosf(a)+n*sinf(a);}
__device__ float3 leafN(const float* P,int id,float time,float wind){int b=id*PS;float3 u=read3(P,b+4);float3 n=read3(P,b+12);float phase=(float)(((int)P[b+15])%8192)*0.618f;float a=wind*(0.11f*sinf(time*2.1f+phase)+0.045f*sinf(time*5.8f+phase*1.7f));return n*cosf(a)-u*sinf(a);}
__device__ float leafWidth(float u,float length,float halfWidth,float footprint){float q=sat(u/length);float s=sinf(PI*q);float lobes=0.77f+0.23f*cosf(q*PI*10.0f+0.45f);float fine=bandWeight(0.002f,footprint)*0.015f*sinf(q*PI*160.0f);return halfWidth*powf(fmaxf(0.0f,s),0.72f)*(lobes+fine);}
__device__ float leafHeight(float u,float v,float len,float halfWidth,float curl,float twist,float footprint){float q=clampf(u/len,-0.2f,1.2f);float s=sinf(PI*q);float coarse=curl*s+twist*(q-0.4f)*v+0.009f*(v*v/(halfWidth*halfWidth))*s;float mid=0.0012f*expf(-fabsf(v)/0.005f)*s*bandWeight(0.007f,footprint);return coarse+mid;}


// === CAMERA ===
// Pointer-lock first-person forest camera.
__device__ void fpsPose(float* C,float3 eye,float yaw,float pitch){C[16]=yaw;C[17]=pitch;C[27]=yaw;C[28]=pitch;write3(C,0,eye);float cp=cosf(pitch);float3 f=norm3(make_float3(sinf(yaw)*cp,sinf(pitch),cosf(yaw)*cp));write3(C,4,eye+f);C[3]=1.0f;C[18]=1.0f;}
__device__ void viewPreset(float* C,const float* P,int preset){if(preset==1)fpsPose(C,make_float3(2.0f,1.72f,18.0f),PI,0.0f);if(preset==2)fpsPose(C,make_float3(-1.4f,1.72f,7.0f),PI*0.94f,0.02f);if(preset==3)fpsPose(C,make_float3(8.0f,1.72f,-3.0f),PI*0.55f,-0.02f);if(preset==4)fpsPose(C,make_float3(-11.0f,1.72f,-7.0f),0.65f,0.03f);if(preset==5)fpsPose(C,make_float3(0.0f,12.0f,72.0f),PI,-0.12f);C[9]=0.0f;C[10]=1.0f;}
__global__ void initCamera(float* C,const float* P,int seed){if(blockIdx.x!=0||threadIdx.x!=0)return;for(int i=0;i<64;i++)C[i]=0.0f;C[12]=-0.45f;C[13]=0.63f;C[14]=0.90f;C[20]=1.18f;C[22]=0.0f;C[23]=1.0f;C[31]=(float)seed;C[44]=1.0f;fpsPose(C,make_float3(2.0f,1.72f,18.0f),PI,0.0f);}
__global__ void updateCamera(float* C,const float* I,const float* P,float delta,int width,int height){if(blockIdx.x!=0||threadIdx.x!=0)return;C[10]=0.0f;C[24]+=1.0f;float dt=clampf(delta,0.0f,0.1f);float3 old=read3(C,0);if(I[5]>0.0f)viewPreset(C,P,(int)I[5]);if(I[7]>0.0f){C[11]=C[11]>0.0f?0.0f:0.60f;C[10]=1.0f;}if(I[9]>0.0f){C[15]=(float)(((int)C[15]+1)%4);C[10]=1.0f;}if(I[10]>0.0f){C[22]=1.0f-C[22];C[10]=1.0f;}if(I[8]!=0.0f){C[12]+=I[8]*dt*0.6f;C[10]=1.0f;}if(I[12]!=0.0f){C[20]=clampf(C[20]+I[12]*dt,0.25f,3.0f);C[10]=1.0f;}if(C[11]>0.0f){C[8]+=dt;C[10]=1.0f;}C[16]-=I[0]*0.00225f;C[17]=clampf(C[17]-I[1]*0.0020f,-1.45f,1.45f);float yaw=C[16];float cp=cosf(C[17]);float3 look=norm3(make_float3(sinf(yaw)*cp,sinf(C[17]),cosf(yaw)*cp));float3 walkF=norm3(make_float3(sinf(yaw),0.0f,cosf(yaw)));float3 right=norm3(make_float3(walkF.z,0.0f,-walkF.x));float speed=(I[16]>0.5f?10.5f:4.2f);float3 move=walkF*I[15]+right*I[13];if(dot3(move,move)>0.0001f)move=norm3(move)*speed*dt;float3 eye=read3(C,0)+move;eye.y=1.72f;write3(C,0,eye);write3(C,4,eye+look);C[27]=C[16];C[28]=C[17];C[3]=1.0f;C[18]=1.0f;if(length3(eye-old)>0.000001f||I[0]!=0.0f||I[1]!=0.0f)C[10]=1.0f;if(C[32]!=(float)width||C[33]!=(float)height){C[10]=1.0f;C[32]=(float)width;C[33]=(float)height;}C[9]=C[10]>0.5f?0.0f:fminf(255.0f,C[9]+1.0f);}


// === TRACE ===
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


// === SHADE ===
__device__ float3 sky(float3 rd,float3 sun){float h=sat(rd.y);float3 c=mix3(make_float3(0.75f,0.79f,0.77f),make_float3(0.19f,0.35f,0.54f),powf(h,0.48f));float warm=powf(sat(dot3(rd,sun)),32.0f);c=c+make_float3(0.48f,0.26f,0.075f)*warm;float disc=smooth(0.99996f,0.999984f,dot3(rd,sun));c=c+make_float3(8.0f,6.7f,4.9f)*disc;float clouds=noise(rd.x*5.0f/(0.2f+h),rd.z*5.0f/(0.2f+h),231);float veil=smooth(0.62f,0.81f,clouds)*smooth(0.02f,0.18f,h)*0.38f;return mix3(c,make_float3(1.1f,1.10f,1.05f),veil);}
__device__ float3 barkColor(const float* P,int id,float3 p,float footprint){int b=id*PS;int seed=(int)P[b+15];float2 uv=woodUV(P,id,p);float3 coord=make_float3(cosf(uv.x)*9.0f,sinf(uv.x)*9.0f,uv.y*7.0f);
 float mottle=noise3(p*3.0f,714);float rough=noise3(coord,seed);float3 d=read3(P,b+4)-read3(P,b);float t=sat(dot3(p-read3(P,b),d)/fmaxf(0.000001f,dot3(d,d)));float amp=fminf(0.021f,lerp(P[b+7],P[b+11],t)*0.055f);float cut=barkCut(P,id,p,footprint)/fmaxf(0.00001f,amp);
 float3 c=mix3(make_float3(0.10f,0.075f,0.050f),make_float3(0.25f,0.21f,0.16f),0.25f+rough*0.62f);c=c*(0.75f+0.35f*mottle);c=c*(1.0f-0.62f*smooth(0.28f,0.85f,cut));
 float moss=smooth(0.52f,0.72f,noise3(p*5.0f,189))*(1.0f-smooth(0.15f,1.4f,p.y));c=mix3(c,make_float3(0.045f,0.064f,0.018f),moss*0.62f);
 float lichen=smooth(0.65f,0.77f,noise3(p*23.0f,27))*smooth(0.25f,0.65f,noise3(p*90.0f,712))*bandWeight(0.018f,footprint);c=mix3(c,make_float3(0.31f,0.33f,0.23f),lichen*0.5f);
 float grain=(noise3(coord*15.0f,seed)-0.5f)*bandWeight(0.0025f,footprint);return c*(1.0f+grain*0.38f);
}
__device__ float leafVein(const float* P,int id,float3 p,float footprint,float time,float wind){int b=id*PS;float3 q=p-read3(P,b);float x=dot3(q,leafU(P,id,time,wind))-P[b+16];float y=dot3(q,read3(P,b+8));float len=P[b+7];float mid=expf(-fabsf(y)/fmaxf(0.00065f,footprint*0.55f));float fy=frac((x-fabsf(y)*0.70f)/len*7.0f);float dd=fminf(fy,1.0f-fy)*len/7.0f;float lateral=expf(-dd/fmaxf(0.00033f,footprint*0.5f));return sat(mid*0.82f+lateral*0.48f)*bandWeight(0.003f,footprint);}
__device__ float3 leafColor(const float* P,int id,float3 p,float fp,float time,float wind){int b=id*PS;float h=rnd((int)P[b+15],887);float3 q=p-read3(P,b);float x=dot3(q,leafU(P,id,time,wind))-P[b+16];if(x<0.0f)return make_float3(0.17f,0.15f,0.048f);float y=dot3(q,read3(P,b+8));float v=leafVein(P,id,p,fp,time,wind);
 float3 c=mix3(make_float3(0.035f,0.11f,0.008f),make_float3(0.15f,0.255f,0.025f),h);c=mix3(c,make_float3(0.22f,0.26f,0.055f),v*0.57f);
 float speck=(noise(x*700.0f,y*700.0f,(int)P[b+15])-0.5f)*bandWeight(0.0017f,fp);float edge=smooth(0.78f,1.0f,fabsf(y)/fmaxf(0.001f,leafWidth(x,P[b+7],P[b+11],fp)));c=c*(1.0f+speck*0.27f);c=mix3(c,make_float3(0.23f,0.20f,0.05f),edge*0.22f);return c;
}
__device__ float3 groundColor(float3 p,float fp){float a=noise(p.x*3.0f,p.z*3.0f,819);float b=noise(p.x*15.0f,p.z*15.0f,28);float r=sqrtf(p.x*p.x+p.z*p.z);float soil=1.0f-smooth(4.1f,6.8f,r+noise(p.x,p.z,13));float3 grass=mix3(make_float3(0.085f,0.115f,0.035f),make_float3(0.23f,0.24f,0.092f),a);float3 dirt=mix3(make_float3(0.075f,0.055f,0.035f),make_float3(0.16f,0.13f,0.080f),b);float moss=smooth(0.53f,0.73f,a);dirt=mix3(dirt,make_float3(0.049f,0.079f,0.022f),moss*0.72f);float grit=(noise(p.x*200.0f,p.z*200.0f,127)-0.5f)*bandWeight(0.007f,fp);return mix3(grass,dirt,soil)*(1.0f+grit*0.40f);}
__device__ float3 surfaceColor(const float* P,int id,float3 p,float fp,float time,float wind){if(id<0)return groundColor(p,fp);int b=id*PS;int type=(int)P[b+3];if(type==0)return barkColor(P,id,p,fp);if(type==1)return leafColor(P,id,p,fp,time,wind);float f=noise3(p*42.0f,(int)P[b+15]);return mix3(make_float3(0.09f,0.10f,0.086f),make_float3(0.31f,0.30f,0.24f),f);}
__device__ float3 lightVisibility(const float* P,const float* Nodes,const unsigned int* Order,float3 p,float3 direction,int original,int originalTree,float time,float wind,int worldSeed){float3 transmission=make_float3(1.0f,1.0f,1.0f);float3 ro=p;
 for(int j=0;j<4;j++){int tree=-1;float2 h=traceForest(P,Nodes,Order,ro,direction,0.0001f,time,wind,36.0f,worldSeed,&tree,true);int id=(int)h.y;if(id<0)break;if(P[id*PS+3]!=1.0f)return make_float3(0.0f,0.0f,0.0f);transmission=transmission*make_float3(0.18f,0.29f,0.065f);ro=ro+direction*(h.x+0.0018f);}
 return transmission;
}
__device__ float3 hemiDirection(float3 n,float r1,float r2){float3 u=basisU(n);float3 v=cross3(n,u);float a=2.0f*PI*r1;float s=sqrtf(r2);return norm3(u*(cosf(a)*s)+v*(sinf(a)*s)+n*sqrtf(1.0f-r2));}
__device__ float specGGX(float3 n,float3 v,float3 l,float rough){float3 h=norm3(v+l);float nh=sat(dot3(n,h));float nv=fmaxf(0.002f,sat(dot3(n,v)));float nl=sat(dot3(n,l));float vh=sat(dot3(v,h));float a=rough*rough;float aa=a*a;float den=nh*nh*(aa-1.0f)+1.0f;float D=aa/(PI*den*den);float k=(rough+1.0f)*(rough+1.0f)*0.125f;float G=nv/(nv*(1.0f-k)+k)*nl/(nl*(1.0f-k)+k);float F=0.035f+0.965f*powf(1.0f-vh,5.0f);return D*G*F/(4.0f*nv+0.0001f);}
__global__ void shadePixels(const float* P,const float* Nodes,const unsigned int* Order,const float* C,const float* Hit,float* Linear,float* Guide,int width,int height){int x=(int)(blockIdx.x*blockDim.x+threadIdx.x);int y=(int)(blockIdx.y*blockDim.y+threadIdx.y);if(x>=width||y>=height)return;int pixel=y*width+x;int b=pixel*4;float t=Hit[b];int id=(int)Hit[b+1];int tree=(int)Hit[b+2];float3 ro=cameraPos(C);float3 rd=cameraRay(C,x,y,width,height);float3 sun=sunC(C);float3 col=sky(rd,sun);float3 guide=make_float3(1.0f,1.0f,1.0f);int worldSeed=(int)C[31];
 if(t<FAR){float3 p=ro+rd*t;float fp=fmaxf(0.000005f,Hit[b+3]);float3 localP=p;float3 n=make_float3(0.0f,1.0f,0.0f);float localFp=fp;float phase=0.0f;
  if(id>=0&&tree>=0){float sc=forestScale(tree,worldSeed);localP=forestToLocalPoint(p,tree,worldSeed);localFp=fp/sc;phase=(float)(forestSeed(tree,worldSeed)&8191)*0.0017f;n=forestToWorldNormal(objectNormal(P,id,localP,localFp,C[8]+phase,C[11]),tree,worldSeed);}bool leaf=id>=0&&P[id*PS+3]==1.0f;
  if(dot3(n,rd)>0.0f)n=n*-1.0f;
  if(id<0){float e=fmaxf(0.001f,fp);float nx=(noise((p.x+e)*18.0f,p.z*18.0f,133)-noise((p.x-e)*18.0f,p.z*18.0f,133))*0.18f;float nz=(noise(p.x*18.0f,(p.z+e)*18.0f,133)-noise(p.x*18.0f,(p.z-e)*18.0f,133))*0.18f;n=norm3(make_float3(nx,1.0f,nz));}
  float3 albedo=surfaceColor(P,id,id>=0?localP:p,localFp,C[8]+phase,C[11]);if(tree>=0){int ts=forestSeed(tree,worldSeed);float hue=rnd(8,ts);float age=rnd(9,ts);float season=rnd(10,ts);float dark=0.76f+age*0.38f;float3 tint=make_float3(0.88f+0.22f*hue,0.84f+0.28f*(1.0f-fabsf(hue-0.55f)),0.72f+0.25f*(1.0f-hue));if(leaf)tint=mix3(tint,make_float3(1.12f,0.88f,0.48f),smooth(0.78f,0.98f,season)*0.38f);else tint=mix3(tint,make_float3(0.78f,0.66f,0.53f),season*0.18f);albedo=albedo*tint*dark;}guide=albedo;int sample=(int)C[9];float r1=rnd(pixel+sample*1823,991);float r2=rnd(pixel+sample*971,731);float3 su=basisU(sun);float3 sv=cross3(sun,su);float angle=r1*6.28318f;float disk=sqrtf(r2)*0.012f;float3 light=norm3(sun+su*(cosf(angle)*disk)+sv*(sinf(angle)*disk));
  float offset=id>=0?0.0014f:0.004f;float3 visibility=make_float3(1.0f,1.0f,1.0f);if(C[22]>0.5f)visibility=lightVisibility(P,Nodes,Order,p+light*offset,light,id,tree,C[8],C[11],worldSeed);
  float nl=sat(dot3(n,light));float back=sat(-dot3(n,light));float3 direct=albedo*(nl/PI);if(leaf){float vein=leafVein(P,id,localP,localFp,C[8]+phase,C[11]);direct=direct+albedo*(back*(0.75f-0.25f*vein)+powf(sat(dot3(rd,light)),9.0f)*0.12f);}float spec=specGGX(n,rd*-1.0f,light,leaf?0.39f:0.82f);direct=direct+make_float3(spec,spec,spec);
  float ao=1.0f;float3 ambient=make_float3(0.30f,0.37f,0.45f)*(0.45f+0.55f*sat(n.y))*ao+make_float3(0.08f,0.068f,0.035f)*sat(-n.y);if(leaf)ambient=ambient+make_float3(0.04f,0.055f,0.022f)*ao;col=direct*visibility*make_float3(4.8f,4.2f,3.1f)+albedo*ambient;
  float haze=1.0f-expf(-t*0.0018f);col=mix3(col,sky(rd,sun),haze);if(C[15]==1.0f){float w0=bandWeight(0.065f,localFp);float w1=bandWeight(0.005f,localFp);float w2=bandWeight(0.001f,localFp);col=make_float3(w0*0.80f,w1*0.85f,w2*0.9f);}if(C[15]==2.0f){float h=rnd(id+177+(tree+1)*71,32);col=id<0?make_float3(0.10f,0.10f,0.10f):(leaf?make_float3(0.1f,0.3f+h*0.5f,0.17f):make_float3(0.47f+h*0.3f,0.25f,0.10f));}if(C[15]==3.0f)col=n*0.5f+make_float3(0.5f,0.5f,0.5f);
 }
 write3(Linear,b,col);Linear[b+3]=1.0f;write3(Guide,b,guide);Guide[b+3]=1.0f;
}
// A same-surface lighting filter, not an alpha fade. Demodulation keeps bark
// colour and leaf veins sharp. No mixing across distinct leaf IDs or depth edges.
__global__ void filterLighting(const float* Linear,const float* Guide,const float* Hit,float* Filtered,const float* C,int width,int height){
 int x=(int)(blockIdx.x*blockDim.x+threadIdx.x);int y=(int)(blockIdx.y*blockDim.y+threadIdx.y);if(x>=width||y>=height)return;int b=(y*width+x)*4;
 float3 col=read3(Linear,b);float3 base=read3(Guide,b)+make_float3(0.02f,0.02f,0.02f);float3 sum=make_float3(0.0f,0.0f,0.0f);float weight=0.0f;int id=(int)Hit[b+1];float depth=Hit[b];
 if(depth<FAR&&C[15]<0.5f){for(int j=-2;j<=2;j++)for(int k=-2;k<=2;k++){
  int xx=x+k;int yy=y+j;if(xx<0||yy<0||xx>=width||yy>=height)continue;int q=(yy*width+xx)*4;
  if((int)Hit[q+1]!=id||(int)Hit[q+2]!=(int)Hit[b+2]||fabsf(Hit[q]-depth)>fmaxf(0.005f,Hit[b+3]*6.0f))continue;
  float w=expf(-(float)(j*j+k*k)*0.30f);float3 c=read3(Linear,q);float3 g=read3(Guide,q)+make_float3(0.02f,0.02f,0.02f);
  sum=sum+make_float3(c.x/g.x,c.y/g.y,c.z/g.z)*w;weight+=w;
 }if(weight>0.0f)col=mix3(col,(sum/weight)*base,0.86f);}
 write3(Filtered,b,col);Filtered[b+3]=1.0f;
}
__device__ float aces(float x){return sat((x*(2.51f*x+0.03f))/(x*(2.43f*x+0.59f)+0.14f));}
__global__ void resolvePixels(const float* Filtered,float* History,unsigned int* Pixels,const float* C,int width,int height){int x=(int)(blockIdx.x*blockDim.x+threadIdx.x);int y=(int)(blockIdx.y*blockDim.y+threadIdx.y);if(x>=width||y>=height)return;int i=y*width+x;int b=i*4;float3 current=read3(Filtered,b);float count=C[10]>0.5f?0.0f:C[9];float3 mean=count<0.5f?current:mix3(read3(History,b),current,1.0f/(count+1.0f));write3(History,b,mean);History[b+3]=count+1.0f;float3 col=mean*C[20];col=make_float3(aces(col.x),aces(col.y),aces(col.z));col=make_float3(powf(col.x,1.0f/2.2f),powf(col.y,1.0f/2.2f),powf(col.z,1.0f/2.2f));float u=((float)x/(float)width-0.5f)*2.0f;float v=((float)y/(float)height-0.5f)*2.0f;col=col*(1.0f-0.09f*(u*u+v*v));Pixels[i]=packRGB(col);}
