//
//  CenterResize.metal
//  Anime4KMetal
//
//  Created by Yi Xie on 2023/03/26.
//

#include <metal_stdlib>
using namespace metal;

constant float inW [[function_constant(0)]];
constant float inH [[function_constant(1)]];
constant float outW [[function_constant(2)]];
constant float outH [[function_constant(3)]];

constexpr sampler linearSampler (coord::normalized, address::clamp_to_zero, filter::linear);

kernel void CenterResize(texture2d<float, access::sample> input [[texture(0)]],
                         texture2d<float, access::write> output [[texture(1)]],
                         uint2 gid [[thread_position_in_grid]]) {
    float scale = min(outW / inW, outH / inH);
    float outValidW = inW * scale;
    float outValidH = inH * scale;
    float outPadW = (outW - outValidW) / 2;
    float outPadH = (outH - outValidH) / 2;
    float2 nPos = float2((float(gid.x) - outPadW) / outValidW, (float(gid.y) - outPadH) / outValidH);
    output.write(input.sample(linearSampler, nPos), gid);
}
