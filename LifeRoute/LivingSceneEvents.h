#ifndef LIVING_SCENE_EVENTS_H
#define LIVING_SCENE_EVENTS_H

// Episodic storytelling uses the existing foreground scene clock. These pure
// production states are sampled by both the fragment and the GPU test probe.
// No timers, emitters, persisted state, second renderer or product QA controls.
struct LivingFlightEvent {
    float2 position;
    float2 tangent;
    float wingPhase;
    float state; // 0 roosting, 1 takeoff, 2 flight, 3 landing
    float cycle;
    float eventStart;
};

static LivingFlightEvent livingBatEvent(float t, bool active) {
    float cycle = floor(max(t,0.0)/32.0);
    float local = max(t,0.0)-cycle*32.0;
    float start = 14.0+livingHash(float2(cycle,71.0))*6.0;
    bool reverse = fmod(cycle,2.0) > 0.5;
    float2 left = float2(0.125,0.417), right = float2(0.845,0.405);
    float2 from = reverse ? right : left, to = reverse ? left : right;
    float direction = reverse ? -1.0 : 1.0;
    LivingFlightEvent result = {from,float2(direction,0),0,0,cycle,cycle*32.0+start};
    if (!active) return {left,float2(1,0),0,0,0,0};
    float age = local-start;
    if (age < 0.0) return result;
    if (age >= 11.0) { result.position=to; return result; }
    float2 lift = float2(direction*0.025,-0.038);
    float2 depart = from+lift, approach = to-float2(direction*0.025,0.038);
    if (age < 1.0) {
        result.state=1;
        float u = age*age*(3.0-2.0*age);
        result.position=mix(from,depart,u);
        result.tangent=normalize(lift);
    } else if (age < 10.0) {
        result.state=2;
        float u=(age-1.0)/9.0;
        float arc=0.10+livingHash(float2(cycle,39.0))*0.045;
        result.position=mix(depart,approach,u)+float2(0,-sin(u*M_PI_F)*arc);
        result.tangent=normalize(approach-depart+float2(0,-cos(u*M_PI_F)*arc*M_PI_F));
    } else {
        result.state=3;
        float u=age-10.0;u=u*u*(3.0-2.0*u);
        result.position=mix(approach,to,u);
        result.tangent=normalize(to-approach);
    }
    result.wingPhase=sin(age*(28.0+livingHash(float2(cycle,12.0))*4.0));
    return result;
}

static float livingTriangle(float2 p, float2 a, float2 b, float2 c) {
    float2 ab=b-a,bc=c-b,ca=a-c;
    float area=ab.x*(c-a).y-ab.y*(c-a).x;
    if (abs(area)<0.00001) return 0;
    float orientation=sign(area);
    float e0=((p-a).x*ab.y-(p-a).y*ab.x)*-orientation/max(length(ab),0.00001);
    float e1=((p-b).x*bc.y-(p-b).y*bc.x)*-orientation/max(length(bc),0.00001);
    float e2=((p-c).x*ca.y-(p-c).y*ca.x)*-orientation/max(length(ca),0.00001);
    return smoothstep(-0.045,0.045,min(e0,min(e1,e2)));
}

static float3 livingBat(float3 color,float2 uv,float2 textureSize,float t,bool active) {
    LivingFlightEvent e=livingBatEvent(t,active);
    // Small distant silhouette with local vector anatomy, never an interface
    // glyph. The photographed ledges support two alternating roost locations.
    float2 local=(uv-e.position)*textureSize/10.0;
    if (dot(local,local)>5.0) return color;
    float2 heading=normalize(e.tangent*textureSize);
    float2 side=float2(-heading.y,heading.x);
    float2 q=float2(dot(local,side),-dot(local,heading));
    if (e.state==0) q=float2(local.x,-local.y);
    float body=livingOval(q,float2(0,0.06),float2(0.17,0.30));
    body=max(body,livingOval(q,float2(0,-0.22),float2(0.15,0.14)));
    body=max(body,livingTriangle(q,float2(-0.14,-0.26),float2(-0.12,-0.45),float2(-0.03,-0.28)));
    body=max(body,livingTriangle(q,float2(0.14,-0.26),float2(0.12,-0.45),float2(0.03,-0.28)));
    if (e.state>0) {
        float2 w=float2(abs(q.x),q.y);
        float lift=e.wingPhase*0.72;
        float2 root=float2(0.09,0),tip=float2(1.40-abs(lift)*0.25,lift-0.20);
        float2 finger=float2(0.87,0.14+lift*0.65),elbow=float2(0.55,0.29+lift*0.30);
        body=max(body,livingTriangle(w,root,tip,finger));
        body=max(body,livingTriangle(w,root,finger,elbow));
        body=max(body,livingTriangle(w,root,elbow,float2(0.14,0.27)));
    } else {
        body=max(body,livingOval(q,float2(0,0.09),float2(0.22,0.36)));
    }
    return mix(color,float3(0.008,0.012,0.019),body*0.88);
}


static LivingFlightEvent livingBirdEvent(float t,bool active) {
    float cycle=floor(max(t,0.0)/38.0),local=max(t,0.0)-cycle*38.0;
    float start=18.0+livingHash(float2(cycle,113.0))*7.0;
    bool reverse=fmod(cycle,2.0)>0.5;
    float2 left=float2(0.155,0.655),right=float2(0.842,0.508);
    float2 from=reverse?right:left,to=reverse?left:right;
    float direction=reverse?-1.0:1.0;
    LivingFlightEvent e={from,float2(direction,0),0,0,cycle,cycle*38.0+start};
    if (!active) return {left,float2(1,0),0,0,0,0};
    float age=local-start;
    if (age<0.0) return e;
    if (age>=10.0) {e.position=to;return e;}
    float2 depart=from+float2(direction*0.035,-0.04);
    float2 approach=to-float2(direction*0.03,0.04);
    if (age<1.5) {
        float u=smoothstep(0.0,1.5,age);e.state=1;
        e.position=mix(from,depart,u);e.tangent=normalize(depart-from);
    } else if (age<8.5) {
        float u=(age-1.5)/7.0,arc=0.14+livingHash(float2(cycle,28.0))*0.04;e.state=2;
        e.position=mix(depart,approach,u)+float2(0,-sin(u*M_PI_F)*arc);
        e.tangent=normalize(approach-depart+float2(0,-cos(u*M_PI_F)*arc*M_PI_F));
    } else {
        float u=smoothstep(8.5,10.0,age);e.state=3;
        e.position=mix(approach,to,u);e.tangent=normalize(to-approach);
    }
    e.wingPhase=sin(age*(16.5+livingHash(float2(cycle,44.0))*2.0));
    return e;
}

static float3 livingBird(float3 color,float2 uv,float2 textureSize,float t,bool active) {
    LivingFlightEvent e=livingBirdEvent(t,active);
    float2 local=(uv-e.position)*textureSize/8.0;
    if (dot(local,local)>3.0) return color;
    float2 heading=normalize(e.tangent*textureSize);
    float2 q=float2(dot(local,heading),dot(local,float2(-heading.y,heading.x)));
    if (e.state==0) q=float2(local.x*e.tangent.x,local.y);
    float body=livingOval(q,float2(0,0),float2(0.33,0.17));
    body=max(body,livingOval(q,float2(0.25,-0.12),float2(0.14,0.13)));
    body=max(body,livingTriangle(q,float2(0.35,-0.13),float2(0.57,-0.09),float2(0.35,-0.03)));
    body=max(body,livingTriangle(q,float2(-0.20,0.04),float2(-0.59,0.12),float2(-0.43,-0.10)));
    if (e.state>0) {
        float span=0.20+e.wingPhase*0.95;
        body=max(body,livingTriangle(q,float2(-0.08,0),float2(-0.28,-span),float2(0.09,-span*0.44)));
        body=max(body,livingTriangle(q,float2(-0.08,0),float2(-0.24,span*0.80),float2(0.10,span*0.37)));
    } else {
        body=max(body,livingTriangle(q,float2(-0.05,0.11),float2(-0.01,0.34),float2(0.035,0.13)));
        body=max(body,livingTriangle(q,float2(0.10,0.10),float2(0.13,0.34),float2(0.16,0.10)));
    }
    return mix(color,float3(0.045,0.033,0.022),body*0.9);
}

struct LivingGustEvent { float strength; float travel; float state; float eventStart; };
static LivingGustEvent livingGustEvent(float t) {
    float cycle=floor(max(0.0,t)/32.0),local=max(0.0,t)-cycle*32.0;
    float start=7.0+livingHash(float2(cycle,194.0))*6.0,age=local-start;
    float strength=0,integral=0,state=0;
    if (age>=0.0 && age<1.0) {
        strength=smoothstep(0.0,1.0,age);
        integral=age*age*age-0.5*age*age*age*age;state=1;
    } else if (age>=1.0 && age<5.0) {
        strength=1;integral=age-0.5;state=1;
    } else if (age>=5.0 && age<6.5) {
        float x=age-5.0;
        strength=1.0-smoothstep(0.0,1.5,x);
        integral=4.5+x-x*x*x/2.25+0.5*x*x*x*x/3.375;state=2;
    } else if (age>=6.5) integral=5.25;
    // Integrate the velocity envelope instead of multiplying time by a gust.
    // Particle positions never jump backward as the wind settles or wraps.
    return {strength,(cycle*5.25+integral)*0.035,state,cycle*32.0+start};
}
#endif
