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
