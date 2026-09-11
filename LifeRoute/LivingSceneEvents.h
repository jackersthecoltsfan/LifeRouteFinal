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
    float orientation=sign(ab.x*(c-a).y-ab.y*(c-a).x);
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
    float2 side=float2(-e.tangent.y,e.tangent.x);
    float2 q=float2(dot(local,side),-dot(local,e.tangent));
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
#endif
