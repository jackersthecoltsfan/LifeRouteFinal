#include <metal_stdlib>
using namespace metal;

// Destination-to-source flow of the accepted V04 pixels, in its 340 pt canvas.
// One continuous field flexes the three forms without cutting out image plates.
// Organic form motion remains inside the well. A separate bounded radial band
// lets the accepted shell itself breathe on the shared beat without moving the
// 340-point presentation, its text, or the scenery behind it.
[[ stitchable ]] float2 livingOrbInterior(float2 position, float time,
                                          float energy, float alertness, float pulse) {
    float2 q = position - float2(170.0);
    float radius = length(q);
    if (radius >= 163.0 || energy == 0.0) return position;
    float interiorLock = 1.0 - smoothstep(106.0, 144.0, radius);
    float rear = exp(-dot((position - float2(130, 157)) / float2(68, 100),
                          (position - float2(130, 157)) / float2(68, 100)));
    float2 axis = float2(0.81, 0.5864);
    float2 normal = float2(-axis.y, axis.x);
    float2 mid = position - float2(169, 211);
    float along = dot(mid, axis);
    float across = dot(mid, normal);
    float middle = exp(-along * along / 16900.0 - across * across / 1521.0);
    float2 frontPoint = (position - float2(246, 100)) / float2(46, 49);
    float front = exp(-dot(frontPoint, frontPoint));

    // Unequal periods and travelling spatial phase produce breathing/flexing,
    // diagonal flow and a related foreground counter-response, not rigid parts.
    float breath = sin(time * 1.32 + q.y * 0.007);
    float circulation = sin(time * 1.87 - along * 0.009);
    float alert = alertness * sin(time * 3.05 + q.y * 0.010);
    float2 rearFlow = rear * float2(20.0 * breath + 4.0 * alert,
                                    11.0 * sin(time * 1.09 + q.x * 0.009));
    float2 middleFlow = middle * (axis * (14.0 * circulation)
                         + normal * (11.0 * sin(time * 1.63 - along * 0.012)
                                     + 4.0 * alert));
    float2 frontFlow = front * float2(-14.0 * sin(time * 1.54 + 0.8),
                                       13.0 * sin(time * 1.29 + 1.7));
    // Each form receives a larger but coherent beat response: the rear reaches
    // inward, the diagonal bows along and across its axis, and the foreground
    // lens counters them. Roots remain protected by the same continuous field.
    float2 pulseFlow = pulse * (
        rear * float2(4.0 + 2.0 * sin(time * 1.15 + q.y * 0.012),
                      4.0 * sin(time * 1.34 - q.x * 0.010))
        + middle * (axis * (6.0 + 2.0 * sin(time * 1.28 - along * 0.010))
                    + normal * (5.0 * sin(time * 1.46 + across * 0.014)))
        + front * float2(-5.0 - 2.0 * sin(time * 1.22 + 0.7),
                          4.5 * sin(time * 1.18 + 1.4))
    );
    float rimBand = smoothstep(137.0, 149.0, radius)
        * (1.0 - smoothstep(157.0, 163.0, radius));
    float2 radial = radius > 0.001 ? q / radius : float2(0.0);
    float rimPressure = pulse * rimBand
        * (3.4 + 0.8 * sin(atan2(q.y, q.x) * 3.0 + time * 0.72));
    return position
        + interiorLock * (energy * (rearFlow + middleFlow + frontFlow) + pulseFlow)
        - radial * rimPressure;
}
