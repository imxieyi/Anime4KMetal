//
//  CenterResize.metal
//  Anime4KMetal
//
//  Created by Yi Xie on 2023/03/26.
//

#include <metal_stdlib>
using namespace metal;

constexpr sampler linearSampler (coord::normalized, address::clamp_to_edge, filter::linear);

kernel void CenterResize(texture2d<float, access::sample> input [[texture(0)]],
                         texture2d<float, access::write> output [[texture(1)]],
                         uint2 gid [[thread_position_in_grid]]) {
    float inW = input.get_width();
    float inH = input.get_height();
    float outW = output.get_width();
    float outH = output.get_height();
    float scale = min(outW / inW, outH / inH);
    float outValidW = round(inW * scale);
    float outValidH = round(inH * scale);
    float outPadW = round((outW - outValidW) / 2);
    float outPadH = round((outH - outValidH) / 2);
    float2 nPos = float2((float(gid.x) - outPadW + 0.5) / (outValidW), (float(gid.y) - outPadH + 0.5) / (outValidH));
    if (nPos.x < 0 || nPos.x > 1 || nPos.y < 0 || nPos.y > 1) {
        output.write(float4(0), gid);
        return;
    }
    output.write(input.sample(linearSampler, nPos), gid);
}
