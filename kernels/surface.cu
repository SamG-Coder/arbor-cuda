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
