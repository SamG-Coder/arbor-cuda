// Executes the authored CUDA math/generation/visibility/shading on CPU.
// The cooperative GPU sort has a clearly separate scalar CPU reference below.
// This harness is NOT the shipped renderer and does not certify hardware GPU performance.
#include <algorithm>
#include <cassert>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>
#define __device__
#define __global__
#define __shared__
#define __syncthreads() ((void)0)
struct Index {unsigned int x=0,y=0,z=0;};
thread_local Index threadIdx,blockIdx,blockDim,gridDim;
struct float2 {float x,y;};
struct float3 {float x,y,z;};
struct float4 {float x,y,z,w;};
float2 make_float2(float x,float y){return{x,y};}
float3 make_float3(float x,float y,float z){return{x,y,z};}
float4 make_float4(float x,float y,float z,float w){return{x,y,z,w};}
float3 operator+(float3 a,float3 b){return{a.x+b.x,a.y+b.y,a.z+b.z};}
float3 operator-(float3 a,float3 b){return{a.x-b.x,a.y-b.y,a.z-b.z};}
float3 operator*(float3 a,float b){return{a.x*b,a.y*b,a.z*b};}
float3 operator*(float a,float3 b){return b*a;}
float3 operator*(float3 a,float3 b){return{a.x*b.x,a.y*b.y,a.z*b.z};}
float3 operator/(float3 a,float b){return{a.x/b,a.y/b,a.z/b};}
#include "../Arbor.cu"
void scalar(){threadIdx={0,0,0};blockIdx={0,0,0};blockDim={1,1,1};}
template<class F>void dispatch1(int n,F f){for(int i=0;i<n;i++){blockDim={128,1,1};blockIdx={unsigned(i/128),0,0};threadIdx={unsigned(i%128),0,0};f();}}
template<class F>void dispatch2(int w,int h,F f){
 #pragma omp parallel for schedule(dynamic,2)
 for(int y=0;y<h;y++)for(int x=0;x<w;x++){blockDim={8,8,1};blockIdx={unsigned(x/8),unsigned(y/8),0};threadIdx={unsigned(x%8),unsigned(y%8),0};f();}
}
void require(bool ok,const char* text){if(!ok)throw std::runtime_error(text);std::cout<<"PASS "<<text<<std::endl;}
struct Renderer {
 std::vector<float> branches=std::vector<float>(CURVES*CS),prims=std::vector<float>(CAPACITY*PS),nodes=std::vector<float>(NODE_COUNT*8),c=std::vector<float>(64),input=std::vector<float>(32);
 std::vector<unsigned int> keys=std::vector<unsigned int>(CAPACITY),order=std::vector<unsigned int>(CAPACITY),pixels;
 std::vector<float>hit,linear,guide,filtered,history;int width=960,height=720;
 Renderer(int seed=1788){for(int level=0;level<5;level++)dispatch1(level==0?9:level==1?12:level==2?72:level==3?288:1728,[&]{growTree(branches.data(),level,seed);});dispatch1(CAPACITY,[&]{makePrimitives(branches.data(),prims.data(),seed);});dispatch1(CAPACITY,[&]{makeKeys(prims.data(),keys.data(),order.data());});
  // Independent CPU sort. GPU bitonic pass is tested separately below.
  std::vector<std::pair<unsigned int,unsigned int>>a;for(int i=0;i<CAPACITY;i++)a.push_back({keys[i],order[i]});std::sort(a.begin(),a.end());for(int i=0;i<CAPACITY;i++){keys[i]=a[i].first;order[i]=a[i].second;}
  dispatch1(CAPACITY,[&]{makeBounds(prims.data(),order.data(),nodes.data());});for(int first=CAPACITY/2;first>=1;first/=2)dispatch1(first,[&]{reduceBounds(nodes.data(),first);});scalar();initCamera(c.data(),prims.data(),seed);resize(width,height);
 }
 void resize(int w,int h){width=w;height=h;hit.assign(w*h*4,0);linear=hit;guide=hit;filtered=hit;history=hit;pixels.assign(w*h,0);}
 void view(int p){scalar();input[5]=float(p);updateCamera(c.data(),input.data(),prims.data(),1.0f/60,width,height);input[5]=0;}
 void frame(){dispatch2(width,height,[&]{tracePixels(prims.data(),nodes.data(),order.data(),c.data(),hit.data(),width,height);});dispatch2(width,height,[&]{shadePixels(prims.data(),nodes.data(),order.data(),c.data(),hit.data(),linear.data(),guide.data(),width,height);});dispatch2(width,height,[&]{filterLighting(linear.data(),guide.data(),hit.data(),filtered.data(),c.data(),width,height);});dispatch2(width,height,[&]{resolvePixels(filtered.data(),history.data(),pixels.data(),c.data(),width,height);});}
 void save(std::string file){std::ofstream f(file,std::ios::binary);f<<"P6\n"<<width<<" "<<height<<"\n255\n";for(auto p:pixels){char rgb[3]={char(p&255u),char((p>>8)&255u),char((p>>16)&255u)};f.write(rgb,3);}std::cout<<"RENDER "<<file<<" "<<width<<"x"<<height<<"\n";}
};
int main(int argc,char**argv){try{
 Renderer r;
 std::cout<<"SCENE "<<CURVES<<" curves / "<<WOOD_COUNT<<" woody segments / "<<LEAF_COUNT<<" leaves / "<<ROCK_COUNT<<" stones\n";
 std::cout<<"BOUNDS "<<r.nodes[8]<<","<<r.nodes[9]<<","<<r.nodes[10]<<" to "<<r.nodes[12]<<","<<r.nodes[13]<<","<<r.nodes[14]<<std::endl;
 if(argc>1&&std::string(argv[1])=="render"){
  int view=argc>3?std::stoi(argv[3]):1;int w=argc>4?std::stoi(argv[4]):960;int h=argc>5?std::stoi(argv[5]):720;int samples=argc>6?std::stoi(argv[6]):4;bool light=argc>7?std::stoi(argv[7])!=0:true;
  if(w<32||h<32||w>4096||h>4096||samples<1||samples>512)throw std::runtime_error("Invalid render dimensions/samples");r.resize(w,h);r.view(view);r.c[22]=light?1:0;
  for(int i=0;i<samples;i++){r.c[9]=float(i);r.c[10]=i==0?1:0;r.frame();std::cerr<<"sample "<<i+1<<"/"<<samples<<std::endl;}
  r.save(argc>2?argv[2]:"arbor.ppm");return 0;
 }
 require(std::all_of(r.prims.begin(),r.prims.end(),[](float a){return std::isfinite(a);}),"generated primitive values finite");
 int wood=0,leaves=0,rocks=0;for(int i=0;i<CAPACITY;i++){int ty=int(r.prims[i*PS+3]);wood+=ty==0;leaves+=ty==1;rocks+=ty==2;}
 require(wood==WOOD_COUNT&&leaves==LEAF_COUNT&&rocks==ROCK_COUNT,"exact fixed geometry counts");
 require(int(r.nodes[11])==OBJECT_COUNT,"BVH root includes all active objects");
 bool bounds=true;for(int id=1;id<CAPACITY;id++){int b=id*8;for(int c=0;c<2;c++){int n=(id*2+c)*8;if(r.nodes[n+3]>0)for(int d=0;d<3;d++)if(r.nodes[n+d]<r.nodes[b+d]-1e-5f||r.nodes[n+4+d]>r.nodes[b+4+d]+1e-5f)bounds=false;}}
 require(bounds,"BVH child boxes contained by every parent");
 auto geom=r.prims;for(int view=1;view<=5;view++)r.view(view);require(geom==r.prims,"camera changes never regenerate or replace topology");
 r.view(1);r.input[17]=1.0f;r.view(0);r.input[17]=0.0f;for(int frame=0;frame<800;frame++)r.view(0);
 require(std::abs(r.c[3]-0.22f)<0.001f&&r.c[34]==0.0f&&geom==r.prims,"ten-second approach reaches close-up without touching tree geometry");
 Renderer other(42);require(other.prims!=r.prims&&int(other.nodes[11])==OBJECT_COUNT,"different seed changes layout but preserves topology counts");

 // Compare the authored parallel bitonic algorithm (serially dispatched here)
 // against the independently sorted reference, including duplicate-key tie breaks.
 std::vector<unsigned int> k(CAPACITY),o(CAPACITY);dispatch1(CAPACITY,[&]{makeKeys(r.prims.data(),k.data(),o.data());});
 for(int span=2;span<=CAPACITY;span*=2)for(int distance=span/2;distance>0;distance/=2)dispatch1(CAPACITY,[&]{sortPass(k.data(),o.data(),distance,span);});
 require(k==r.keys&&o==r.order,"bitonic kernel stages equal independent std::sort");
 r.view(1);int mismatches=0;float maxError=0;
 for(int ray=0;ray<100;ray++){
  float3 ro={rnd(ray,198)*24-12,1+rnd(ray,31)*14,rnd(ray,78)*24-12};float3 target={rnd(ray,211)*10-5,2+rnd(ray,433)*8,rnd(ray,123)*10-5};float3 rd=norm3(target-ro);
  float2 hit=traceTree(r.prims.data(),r.nodes.data(),r.order.data(),ro,rd,.0005,0,0,FAR,-1,false);float nearest=FAR;int winner=-1;
  for(int id=0;id<OBJECT_COUNT;id++){auto a=boxSpan(ro,rd,boundLow(r.prims.data(),id),boundHigh(r.prims.data(),id));if(a.y<std::max(.0001f,a.x)||a.x>nearest)continue;float fp=std::max(.000005f,.0005f*std::max(.05f,a.x));float t=objectT(r.prims.data(),id,ro,rd,fp,0,0,true);if(t<nearest){nearest=t;winner=id;}}
  if((hit.y<0)!=(winner<0)||std::abs(nearest-hit.x)>.002f)mismatches++;if(nearest<FAR&&hit.x<FAR)maxError=std::max(maxError,std::abs(nearest-hit.x));
 }
 std::cout<<"BVH max t error "<<maxError<<std::endl;require(mismatches==0,"100 BVH rays match exhaustive intersections");
 bool mono=true,finite=true;float last=1;float jump=0;int id=4;auto point=read3(r.prims.data(),id*PS)+make_float3(0.0f,0.0f,r.prims[id*PS+7]);float prev=barkCut(r.prims.data(),id,point,.000001f);
 for(int i=0;i<10000;i++){float f=0.000001f*powf(100000.0f,float(i)/9999);float w=bandWeight(.065f,f);mono&=w<=last+1e-7f;last=w;float cut=barkCut(r.prims.data(),id,point,f);jump=std::max(jump,std::abs(cut-prev));prev=cut;finite&=std::isfinite(cut);}
 require(mono&&finite,"continuous footprint weights bounded, finite and monotone");std::cout<<"CONTINUITY max relief increment across 10000 log-spaced footprints "<<jump<<" metres\n";require(jump<.00005,"no discrete bark-displacement jump in footprint sweep");
 bool leafStable=true;for(int k=0;k<50;k++){int id=WOOD_COUNT+k*431;int b=id*PS;auto u=read3(r.prims.data(),b+4);auto n=read3(r.prims.data(),b+12);auto p=read3(r.prims.data(),b)+u*(r.prims[b+16]+r.prims[b+7]*.5f)+n*.10f;auto rd=n*-1.0f;float a=leafT(r.prims.data(),id,p,rd,.00001f,0,0);float c=leafT(r.prims.data(),id,p,rd,.05f,0,0);leafStable&=a<FAR&&c<FAR&&std::abs(a-c)<.002f;}
 require(leafStable,"same 50 leaf IDs intersect near and far without alpha fade");
 r.resize(160,120);r.view(1);r.frame();require(std::all_of(r.linear.begin(),r.linear.end(),[](float v){return std::isfinite(v)&&v>=0;}),"rendered HDR frame finite and nonnegative");
 std::cout<<"ALL NATIVE CHECKS PASSED (CPU execution; not a hardware-GPU benchmark)\n";
 return 0;
 }catch(const std::exception&e){std::cerr<<"FAIL "<<e.what()<<std::endl;return 1;}}
