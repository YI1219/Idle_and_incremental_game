// Tool-only adapter to the separately built, unmodified libfive kernel.
// Own mesh-distance oracle; no upstream implementation is vendored here.
#include <algorithm>
#include <chrono>
#include <fstream>
#include <iostream>
#include <map>
#include <numeric>
#include <stdexcept>
#include <vector>
#include "libfive/oracle/oracle_storage.hpp"
#include "libfive/oracle/oracle_clause.hpp"
#include "libfive/render/brep/mesh.hpp"
#include "libfive/render/brep/region.hpp"
#include "libfive/render/brep/settings.hpp"
#include "libfive/tree/operations.hpp"

using V=Eigen::Vector3d;
struct Triangle { V a,b,c,n,lo,hi; };
struct Node { V lo,hi; int begin,end,left=-1,right=-1; };
struct Nearest { double distance2=1e100; V point=V::Zero(); int triangle=-1; };

std::vector<Eigen::Vector3f> read_points(const std::string& file) {
    std::ifstream in(file,std::ios::binary|std::ios::ate);
    if(!in)throw std::runtime_error("Missing input "+file);
    auto size=in.tellg();if(size%12)throw std::runtime_error("Invalid vector input");
    in.seekg(0);std::vector<float> raw(size/4);in.read(reinterpret_cast<char*>(raw.data()),size);
    std::vector<Eigen::Vector3f> result;
    for(size_t i=0;i<raw.size();i+=3)result.emplace_back(raw[i],raw[i+1],raw[i+2]);
    return result;
}

// Euclidean closest point: plane projection if inside, otherwise nearest edge.
V closest(const V& p,const Triangle& t) {
    V e=t.b-t.a,f=t.c-t.a,q=p-t.a;
    double ee=e.dot(e),ff=f.dot(f),ef=e.dot(f),den=ee*ff-ef*ef;
    double u=(ff*q.dot(e)-ef*q.dot(f))/den;
    double v=(ee*q.dot(f)-ef*q.dot(e))/den;
    if(u>=0&&v>=0&&u+v<=1)return t.a+u*e+v*f;
    V best=V::Zero();double error=1e100;
    for(auto pair:{std::make_pair(t.a,t.b),std::make_pair(t.b,t.c),std::make_pair(t.c,t.a)}) {
        V d=pair.second-pair.first;
        V point=pair.first+std::clamp((p-pair.first).dot(d)/d.squaredNorm(),0.,1.)*d;
        double candidate=(p-point).squaredNorm();if(candidate<error){error=candidate;best=point;}
    }
    return best;
}

class Source {
public:
    std::vector<Triangle> tris;std::vector<int> order;std::vector<Node> nodes;
    explicit Source(const std::string& path) {
        auto raw=read_points(path);if(raw.empty()||raw.size()%3)throw std::runtime_error("Bad triangle input");
        for(size_t i=0;i<raw.size();i+=3) {
            Triangle t;t.a=raw[i].cast<double>();t.b=raw[i+1].cast<double>();t.c=raw[i+2].cast<double>();
            V cross=-(t.b-t.a).cross(t.c-t.a);
            if(cross.norm()<1e-12)throw std::runtime_error("Degenerate source triangle");
            t.n=cross.normalized();t.lo=t.a.cwiseMin(t.b).cwiseMin(t.c);t.hi=t.a.cwiseMax(t.b).cwiseMax(t.c);tris.push_back(t);
        }
        order.resize(tris.size());std::iota(order.begin(),order.end(),0);build(0,order.size());
    }
    int build(int begin,int end) {
        Node node;node.lo=V::Constant(1e100);node.hi=V::Constant(-1e100);node.begin=begin;node.end=end;
        for(int i=begin;i<end;++i){node.lo=node.lo.cwiseMin(tris[order[i]].lo);node.hi=node.hi.cwiseMax(tris[order[i]].hi);}
        int id=nodes.size();nodes.push_back(node);
        if(end-begin>8) {
            Eigen::Index axis;(node.hi-node.lo).maxCoeff(&axis);int middle=(begin+end)/2;
            std::nth_element(order.begin()+begin,order.begin()+middle,order.begin()+end,[&](int a,int b){return (tris[a].lo[axis]+tris[a].hi[axis])<(tris[b].lo[axis]+tris[b].hi[axis]);});
            int left=build(begin,middle),right=build(middle,end);nodes[id].left=left;nodes[id].right=right;
        }
        return id;
    }
    double box_distance(const V& p,int id) const {
        auto& n=nodes[id];return (n.lo-p).cwiseMax(0.).squaredNorm()+(p-n.hi).cwiseMax(0.).squaredNorm();
    }
    void nearest(const V& p,int id,Nearest& out) const {
        auto& node=nodes[id];if(box_distance(p,id)>out.distance2)return;
        if(node.left<0)for(int j=node.begin;j<node.end;++j) {
            int i=order[j];V q=closest(p,tris[i]);double d=(p-q).squaredNorm();
            if(d<out.distance2){out.distance2=d;out.point=q;out.triangle=i;}
        } else {
            int a=node.left,b=node.right;if(box_distance(p,a)>box_distance(p,b))std::swap(a,b);
            nearest(p,a,out);nearest(p,b,out);
        }
    }
    bool ray_box(const V& p,const V& ray,const Node& node) const {
        double lo=0.,hi=1e100;
        for(int a=0;a<3;++a){double x=(node.lo[a]-p[a])/ray[a],y=(node.hi[a]-p[a])/ray[a];if(x>y)std::swap(x,y);lo=std::max(lo,x);hi=std::min(hi,y);}
        return hi>=lo;
    }
    void intersections(const V& p,const V& ray,int id,std::vector<double>& hits) const {
        auto& node=nodes[id];if(!ray_box(p,ray,node))return;
        if(node.left>=0){intersections(p,ray,node.left,hits);intersections(p,ray,node.right,hits);return;}
        for(int j=node.begin;j<node.end;++j){auto& t=tris[order[j]];V e=t.b-t.a,f=t.c-t.a,h=ray.cross(f);double det=e.dot(h);if(std::abs(det)<1e-12)continue;
            V s=p-t.a,q=s.cross(e);double u=s.dot(h)/det,v=ray.dot(q)/det,d=f.dot(q)/det;
            if(u>=-1e-10&&v>=-1e-10&&u+v<=1.+1e-10&&d>1e-9)hits.push_back(d);
        }
    }
    bool inside(const V& p) const {
        // Three independent oblique rays reduce parity ambiguity at shared edges.
        int votes=0;
        for(V ray:{V(.8731,.3817,.3039),V(.3127,.8911,.3291),V(.2917,.3719,.8813)}) {
            ray.normalize();std::vector<double> hits;intersections(p,ray,0,hits);std::sort(hits.begin(),hits.end());int count=0;double previous=-1.;
            for(double t:hits)if(t-previous>1e-7){++count;previous=t;}
            votes+=count%2;
        }
        return votes>=2;
    }
    std::pair<double,V> sample(const V& p) const {
        Nearest nearest_point;nearest(p,0,nearest_point);double d=std::sqrt(nearest_point.distance2);
        if(d<1e-8)return {0.,tris[nearest_point.triangle].n};
        double sign=inside(p)?-1.:1.;return {sign*d,sign*(p-nearest_point.point)/d};
    }
};

class MeshOracle:public libfive::OracleStorage<> {
    std::shared_ptr<const Source> source;
public:
    explicit MeshOracle(std::shared_ptr<const Source> s):source(s){}
    void evalInterval(libfive::Interval& out) override {
        V center=(lower.cast<double>()+upper.cast<double>())*.5;
        double d=source->sample(center).first;
        double radius=(upper.cast<double>()-lower.cast<double>()).norm()*.5+1e-4;
        out={float(d-radius),float(d+radius)};
    }
    void evalPoint(float& out,size_t index=0) override {out=source->sample(points.col(index).cast<double>()).first;}
    void checkAmbiguous(Eigen::Block<Eigen::Array<bool,1,LIBFIVE_EVAL_ARRAY_SIZE>,1,Eigen::Dynamic> out) override {
        // Conservatively request feature evaluation everywhere. The source
        // adapter supplies one selected SDF gradient, not a full feature fan.
        out.setConstant(true);
    }
    void evalFeatures(boost::container::small_vector<libfive::Feature,4>& out) override {
        out.emplace_back(source->sample(points.col(0).cast<double>()).second.cast<float>());
    }
};
class MeshClause:public libfive::OracleClause {
    std::shared_ptr<const Source> source;
public:
    explicit MeshClause(std::shared_ptr<const Source> s):source(s){}
    std::unique_ptr<libfive::Oracle> getOracle() const override {return std::make_unique<MeshOracle>(source);}
    std::string name() const override {return "YunluExistingMeshProbe";}
};

int main(int argc,char** argv) {
    try {
        if(argc<5)throw std::runtime_error("Usage: probe source.bin output.bin algorithm edited; or probe source.bin query-output.bin query query-points.bin");
        auto source=std::make_shared<Source>(argv[1]);
        if(std::string(argv[3])=="query") {
            auto points=read_points(argv[4]);std::ofstream out(argv[2],std::ios::binary);
            for(auto& p:points){auto value=source->sample(p.cast<double>());
                if(argc>5&&std::string(argv[5])=="1") {
                    V rel=p.cast<double>()-V(-15,3.25,3);double plane=rel.y(),sphere=4.-rel.norm();
                    double cut=std::min(plane,sphere);
                    if(cut>value.first){value.first=cut;value.second=plane<sphere?V(0,1,0):V(-rel.normalized());}
                }
                float raw[4]={float(value.first),float(value.second.x()),float(value.second.y()),float(value.second.z())};out.write(reinterpret_cast<char*>(raw),sizeof(raw));}
            std::cout<<"SOURCE QUERIES "<<points.size()<<std::endl;return 0;
        }
        using namespace libfive;
        Tree shape(std::make_unique<MeshClause>(source));bool edited=std::stoi(argv[4])!=0;
        if(edited) {
            auto x=Tree::X()+15.,y=Tree::Y()-3.25,z=Tree::Z()-3.;
            shape=max(shape,min(y,4.-sqrt(square(x)+square(y)+square(z))));
        }
        BRepSettings settings;settings.min_feature=.25;settings.max_err=1e-8;settings.workers=4;settings.alg=BRepAlgorithm(std::stoi(argv[3]));
        auto start=std::chrono::steady_clock::now();
        auto mesh=Mesh::render(shape,Region<3>({-23,-6,-5},{-7,10,11}),settings);
        if(!mesh||mesh->branes.empty())throw std::runtime_error("Kernel returned empty mesh");
        std::ofstream out(argv[2],std::ios::binary);double signed_volume=0.;
        std::map<std::pair<uint32_t,uint32_t>,std::pair<int,int>> edges;size_t tiny_faces=0;
        for(auto& face:mesh->branes)for(int j:{0,2,1}) {auto& p=mesh->verts[face[j]];float raw[3]={p.x(),p.y(),p.z()};out.write(reinterpret_cast<char*>(raw),sizeof(raw));}
        for(auto& f:mesh->branes){
            V a=mesh->verts[f[0]].cast<double>(),b=mesh->verts[f[1]].cast<double>(),c=mesh->verts[f[2]].cast<double>();signed_volume+=a.dot(b.cross(c))/6.;
            tiny_faces+=(b-a).cross(c-a).squaredNorm()<1e-20;
            for(int j=0;j<3;++j){uint32_t x=f[j],y=f[(j+1)%3];auto& edge=edges[{std::min(x,y),std::max(x,y)}];edge.first++;edge.second+=x<y?1:-1;}
        }
        size_t bad_edges=0;for(auto& edge:edges)bad_edges+=edge.second.first!=2||edge.second.second!=0;
        std::cout<<"LIBFIVE RESULT triangles="<<mesh->branes.size()<<" vertices="<<mesh->verts.size()-1<<" signed_volume="<<signed_volume<<" raw_index_edge_defects="<<bad_edges<<" squared_cross_below_1e20="<<tiny_faces<<" elapsed_seconds="<<std::chrono::duration<double>(std::chrono::steady_clock::now()-start).count()<<std::endl;
        return 0;
    }catch(const std::exception& e){std::cerr<<"PROBE ERROR: "<<e.what()<<std::endl;return 1;}
}
