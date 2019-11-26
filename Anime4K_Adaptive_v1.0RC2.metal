//
//  Anime4K_Adaptive_v1.0RC2.metal
//  Anime4K-tvOS
//
//  Created by 谢宜 on 2019/11/26.
//  Copyright © 2019 xieyi. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

constant float in_w [[function_constant(0)]];
constant float in_h [[function_constant(1)]];
constant float out_w [[function_constant(2)]];
constant float out_h [[function_constant(3)]];

#define origin_size float2(in_w, in_h)
#define destination_size float2(out_w, out_h)

using vec2 = float2;
using vec3 = float3;
using vec4 = float4;

#define HOOKED_tex(pos) hooked.sample(smp, pos)
#define HOOKED_pos pos
#define HOOKED_pt (vec2(1, 1) / origin_size)

#define LUMA_tex(pos) luma.sample(smp, pos)
#define LUMAX_pt (vec2(1, 1) / origin_size)

#define LUMAG_tex(pos) lumag.sample(smp, pos)

#define LUMAD_tex(pos) lumad.sample(smp, pos)

#define LUMA_size origin_size
#define SCALED_size destination_size

kernel void Luminance(texture2d<float, access::sample> input  [[texture(0)]],
                      texture2d<float, access::write> luma [[texture(1)]],
                      uint2 gid [[thread_position_in_grid]]) {
    float4 c = input.read(gid);
    luma.write(0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b, gid);
}

//Anime4K GLSL v1.0 Release Candidate 2

// MIT License

// Copyright (c) 2019 bloc97, DextroseRe

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

//!DESC Anime4K-Luma-v1.0RC2
//!WHEN OUTPUT.w LUMA.w / 1.400 > OUTPUT.h LUMA.h / 1.400 > *
//!HOOK LUMA
//!BIND HOOKED
//!WIDTH OUTPUT.w
//!HEIGHT OUTPUT.h
//!SAVE LUMAX
//!COMPONENTS 1

vec4 hookLuma(texture2d<float, access::sample> hooked,
              sampler smp,
              float2 pos) {
    return HOOKED_tex(HOOKED_pos);
}

kernel void Luma(texture2d<float, access::sample> hooked  [[texture(0)]],
                 texture2d<float, access::write> lumax [[texture(1)]],
                 sampler smp [[ sampler(0) ]],
                 uint2 gid [[thread_position_in_grid]]) {
    float2 pos = float2(gid) / origin_size;
    lumax.write(hookLuma(hooked, smp, pos), gid);
}

//!DESC Anime4K-ComputeGaussianX-v1.0RC2
//!WHEN OUTPUT.w LUMA.w / 1.400 > OUTPUT.h LUMA.h / 1.400 > *
//!HOOK LUMA
//!BIND HOOKED
//!BIND LUMAX
//!SAVE LUMAG
//!COMPONENTS 1

float lumGaussian7(vec2 pos, vec2 d, texture2d<float, access::sample> luma, sampler smp) {
    float g = LUMA_tex(pos - (d * 3)).x * 0.121597;
    g = g + LUMA_tex(pos - (d * 2)).x * 0.142046;
    g = g + LUMA_tex(pos - d).x * 0.155931;
    g = g + LUMA_tex(pos).x * 0.160854;
    g = g + LUMA_tex(pos + d).x * 0.155931;
    g = g + LUMA_tex(pos + (d * 2)).x * 0.142046;
    g = g + LUMA_tex(pos + (d * 3)).x * 0.121597;
    
    return clamp(g, 0.0f, 1.0f); //Clamp for sanity check
}

vec4 hookComputeGaussianX(texture2d<float, access::sample> luma,
                          sampler smp,
                          vec2 pos) {
    float g = lumGaussian7(HOOKED_pos, vec2(LUMAX_pt.x, 0), luma, smp);
    return vec4(g, 0, 0, 0);
}

kernel void ComputeGaussianX(texture2d<float, access::sample> luma  [[texture(0)]],
                        texture2d<float, access::write> lumag [[texture(1)]],
                        sampler smp [[ sampler(0) ]],
                        uint2 gid [[thread_position_in_grid]]) {
    float2 pos = float2(gid) / origin_size;
    lumag.write(hookComputeGaussianX(luma, smp, pos), gid);
}



//!DESC Anime4K-ComputeGaussianY-v1.0RC2
//!WHEN OUTPUT.w LUMA.w / 1.400 > OUTPUT.h LUMA.h / 1.400 > *
//!HOOK LUMA
//!BIND HOOKED
//!BIND LUMAX
//!BIND LUMAG
//!SAVE LUMAG
//!COMPONENTS 1


float lumGaussian7G(vec2 pos, vec2 d, texture2d<float, access::sample> lumag, sampler smp) {
    float g = LUMAG_tex(pos - (d * 3)).x * 0.121597;
    g = g + LUMAG_tex(pos - (d * 2)).x * 0.142046;
    g = g + LUMAG_tex(pos - d).x * 0.155931;
    g = g + LUMAG_tex(pos).x * 0.160854;
    g = g + LUMAG_tex(pos + d).x * 0.155931;
    g = g + LUMAG_tex(pos + (d * 2)).x * 0.142046;
    g = g + LUMAG_tex(pos + (d * 3)).x * 0.121597;
    
    return clamp(g, 0.0f, 1.0f); //Clamp for sanity check
}

vec4 hookComputeGaussianY(texture2d<float, access::sample> lumag,
                          sampler smp,
                          vec2 pos) {
    float g = lumGaussian7G(HOOKED_pos, vec2(0, LUMAX_pt.y), lumag, smp);
    return vec4(g, 0, 0, 0);
}

kernel void ComputeGaussianY(texture2d<float, access::sample> lumag  [[texture(0)]],
                        texture2d<float, access::write> lumagg [[texture(1)]],
                        sampler smp [[ sampler(0) ]],
                        uint2 gid [[thread_position_in_grid]]) {
    float2 pos = float2(gid) / origin_size;
    lumagg.write(hookComputeGaussianY(lumag, smp, pos), gid);
}


//!DESC Anime4K-LineDetect-v1.0RC2
//!WHEN OUTPUT.w LUMA.w / 1.400 > OUTPUT.h LUMA.h / 1.400 > *
//!HOOK LUMA
//!BIND HOOKED
//!BIND LUMAG
//!SAVE LUMAG
//!COMPONENTS 1

#define BlendColorDodgef(base, blend)     (((blend) == 1.0) ? (blend) : min((base) / (1.0 - (blend)), 1.0))
#define BlendColorDividef(top, bottom)     (((bottom) == 1.0) ? (bottom) : min((top) / (bottom), 1.0))

// Component wise blending
#define Blend(base, blend, funcf)         vec3(funcf(base.r, blend.r), funcf(base.g, blend.g), funcf(base.b, blend.b))
#define BlendColorDodge(base, blend)     Blend(base, blend, BlendColorDodgef)


vec4 hookLineDetect(texture2d<float, access::sample> luma,
                    texture2d<float, access::sample> lumag,
                    sampler smp,
                    float2 pos) {
    float lum = clamp(LUMA_tex(HOOKED_pos).x, 0.001, 0.999);
    float lumg = clamp(LUMAG_tex(HOOKED_pos).x, 0.001, 0.999);
    
    float pseudolines = BlendColorDividef(lum, lumg);
    pseudolines = 1 - clamp(pseudolines - 0.05, 0.0f, 1.0f);
    
    return vec4(pseudolines, 0, 0, 0);
}

kernel void LineDetect(texture2d<float, access::sample> luma  [[texture(0)]],
                        texture2d<float, access::sample> lumag [[texture(1)]],
                        texture2d<float, access::write> lumagg [[texture(2)]],
                        sampler smp [[ sampler(0) ]],
                        uint2 gid [[thread_position_in_grid]]) {
    float2 pos = float2(gid) / origin_size;
    lumagg.write(hookLineDetect(luma, lumag, smp, pos), gid);
}



//!DESC Anime4K-ComputeLineGaussianX-v1.0RC2
//!WHEN OUTPUT.w LUMA.w / 1.400 > OUTPUT.h LUMA.h / 1.400 > *
//!HOOK LUMA
//!BIND HOOKED
//!BIND LUMAX
//!BIND LUMAG
//!SAVE LUMAG
//!COMPONENTS 1

vec4 hookComputeLineGaussianX(texture2d<float, access::sample> lumag,
                              sampler smp,
                              float2 pos) {
    float g = lumGaussian7G(HOOKED_pos, vec2(LUMAX_pt.x, 0), lumag, smp);
    return vec4(g, 0, 0, 0);
}

kernel void ComputeLineGaussianX(texture2d<float, access::sample> lumag  [[texture(0)]],
                                 texture2d<float, access::write> lumagg [[texture(1)]],
                                 sampler smp [[ sampler(0) ]],
                                 uint2 gid [[thread_position_in_grid]]) {
    float2 pos = float2(gid) / origin_size;
    lumagg.write(hookComputeLineGaussianX(lumag, smp, pos), gid);
}



//!DESC Anime4K-ComputeLineGaussianY-v1.0RC2
//!WHEN OUTPUT.w LUMA.w / 1.400 > OUTPUT.h LUMA.h / 1.400 > *
//!HOOK LUMA
//!BIND HOOKED
//!BIND LUMAX
//!BIND LUMAG
//!SAVE LUMAG
//!COMPONENTS 1

vec4 hookComputeLineGaussianY(texture2d<float, access::sample> lumag,
                              sampler smp,
                              float2 pos) {
    float g = lumGaussian7G(HOOKED_pos, vec2(0, LUMAX_pt.y), lumag, smp);
    return vec4(g, 0, 0, 0);
}

kernel void ComputeLineGaussianY(texture2d<float, access::sample> lumag  [[texture(0)]],
                                 texture2d<float, access::write> lumagg [[texture(1)]],
                                 sampler smp [[ sampler(0) ]],
                                 uint2 gid [[thread_position_in_grid]]) {
    float2 pos = float2(gid) / origin_size;
    lumagg.write(hookComputeLineGaussianY(lumag, smp, pos), gid);
}


//!DESC Anime4K-ComputeGradientX-v1.0RC2
//!WHEN OUTPUT.w LUMA.w / 1.400 > OUTPUT.h LUMA.h / 1.400 > *
//!HOOK LUMA
//!BIND HOOKED
//!BIND LUMAX
//!SAVE LUMAD
//!COMPONENTS 2

vec4 hookComputeGradientX(texture2d<float, access::sample> luma,
                          sampler smp,
                          float2 pos) {
    vec2 d = LUMAX_pt;
    
    //[tl  t tr]
    //[ l  c  r]
    //[bl  b br]
    float l = LUMA_tex(HOOKED_pos + vec2(-d.x, 0)).x;
    float c = LUMA_tex(HOOKED_pos).x;
    float r = LUMA_tex(HOOKED_pos + vec2(d.x, 0)).x;
    
    
    //Horizontal Gradient
    //[-1  0  1]
    //[-2  0  2]
    //[-1  0  1]
    float xgrad = (-l + r);
    
    //Vertical Gradient
    //[-1 -2 -1]
    //[ 0  0  0]
    //[ 1  2  1]
    float ygrad = (l + c + c + r);
    
    //Computes the luminance's gradient
    return vec4(xgrad, ygrad, 0, 0);
}

kernel void ComputeGradientX(texture2d<float, access::sample> luma  [[texture(0)]],
                             texture2d<float, access::write> lumad [[texture(1)]],
                             sampler smp [[ sampler(0) ]],
                             uint2 gid [[thread_position_in_grid]]) {
    float2 pos = float2(gid) / origin_size;
    lumad.write(hookComputeGradientX(luma, smp, pos), gid);
}


//!DESC Anime4K-ComputeGradientY-v1.0RC2
//!HOOK LUMA
//!BIND HOOKED
//!BIND LUMAX
//!WHEN OUTPUT.w LUMA.w / 1.400 > OUTPUT.h LUMA.h / 1.400 > *
//!BIND LUMAD
//!SAVE LUMAD
//!COMPONENTS 1

vec4 hookComputeGradientY(texture2d<float, access::sample> lumad  [[texture(0)]],
                          sampler smp,
                          float2 pos) {
    vec2 d = LUMAX_pt;
    
    //[tl  t tr]
    //[ l cc  r]
    //[bl  b br]
    float tx = LUMAD_tex(HOOKED_pos + vec2(0, -d.y)).x;
    float cx = LUMAD_tex(HOOKED_pos).x;
    float bx = LUMAD_tex(HOOKED_pos + vec2(0, d.y)).x;
    
    
    float ty = LUMAD_tex(HOOKED_pos + vec2(0, -d.y)).y;
    //float cy = LUMAD_tex(HOOKED_pos).y;
    float by = LUMAD_tex(HOOKED_pos + vec2(0, d.y)).y;
    
    
    //Horizontal Gradient
    //[-1  0  1]
    //[-2  0  2]
    //[-1  0  1]
    float xgrad = (tx + cx + cx + bx);
    
    //Vertical Gradient
    //[-1 -2 -1]
    //[ 0  0  0]
    //[ 1  2  1]
    float ygrad = (-ty + by);
    
    //Computes the luminance's gradient
    return vec4(1 - clamp(sqrt(xgrad * xgrad + ygrad * ygrad), 0.0f, 1.0f), 0, 0, 0);
}

kernel void ComputeGradientY(texture2d<float, access::sample> lumad  [[texture(0)]],
                                 texture2d<float, access::write> lumadd [[texture(1)]],
                                 sampler smp [[ sampler(0) ]],
                                 uint2 gid [[thread_position_in_grid]]) {
    float2 pos = float2(gid) / origin_size;
    lumadd.write(hookComputeGradientY(lumad, smp, pos), gid);
}


#undef HOOKED_pt
#define HOOKED_pt (vec2(1, 1) / destination_size)

//!DESC Anime4K-ThinLines-v1.0RC2
//!HOOK SCALED
//!BIND HOOKED
//!BIND LUMA
//!WHEN OUTPUT.w LUMA.w / 1.400 > OUTPUT.h LUMA.h / 1.400 > *
//!BIND LUMAG

#define LINE_DETECT_THRESHOLD 0.06

#define lineprob (LUMAG_tex(HOOKED_pos).x)

float getLum(vec4 rgb) {
    return (rgb.r + rgb.r + rgb.g + rgb.g + rgb.g + rgb.b) / 6.0;
}

vec4 getLargest(vec4 cc, vec4 lightestColor, vec4 a, vec4 b, vec4 c) {
    float strength = min((SCALED_size.x) / (LUMA_size.x) / 6.0, 1.0f);
    vec4 newColor = cc * (1 - strength) + ((a + b + c) / 3.0) * strength;
    if (newColor.a > lightestColor.a) {
        return newColor;
    }
    return lightestColor;
}

vec4 getRGBL(vec2 pos,
             texture2d<float, access::sample> hooked,
             texture2d<float, access::sample> luma,
             sampler smp) {
    return vec4(HOOKED_tex(pos).rgb, LUMA_tex(pos).x);
}

float min3v(vec4 a, vec4 b, vec4 c) {
    return min(min(a.a, b.a), c.a);
}
float max3v(vec4 a, vec4 b, vec4 c) {
    return max(max(a.a, b.a), c.a);
}


vec4 hookThinLines(texture2d<float, access::sample> hooked,
                   texture2d<float, access::sample> luma,
                   texture2d<float, access::sample> lumag,
                   sampler smp,
                   vec2 pos)  {

    if (lineprob < LINE_DETECT_THRESHOLD) {
        return HOOKED_tex(HOOKED_pos);
    }

    vec2 d = HOOKED_pt;
    
    vec4 cc = getRGBL(HOOKED_pos, hooked, luma, smp);
    
    
    vec4 t = getRGBL(HOOKED_pos + vec2(0, -d.y), hooked, luma, smp);
    vec4 tl = getRGBL(HOOKED_pos + vec2(-d.x, -d.y), hooked, luma, smp);
    vec4 tr = getRGBL(HOOKED_pos + vec2(d.x, -d.y), hooked, luma, smp);
    
    vec4 l = getRGBL(HOOKED_pos + vec2(-d.x, 0), hooked, luma, smp);
    vec4 r = getRGBL(HOOKED_pos + vec2(d.x, 0), hooked, luma, smp);
    
    vec4 b = getRGBL(HOOKED_pos + vec2(0, d.y), hooked, luma, smp);
    vec4 bl = getRGBL(HOOKED_pos + vec2(-d.x, d.y), hooked, luma, smp);
    vec4 br = getRGBL(HOOKED_pos + vec2(d.x, d.y), hooked, luma, smp);
    
    vec4 lightestColor = cc;

    //Kernel 0 and 4
    float maxDark = max3v(br, b, bl);
    float minLight = min3v(tl, t, tr);
    
    if (minLight > cc.a && minLight > maxDark) {
        lightestColor = getLargest(cc, lightestColor, tl, t, tr);
    } else {
        maxDark = max3v(tl, t, tr);
        minLight = min3v(br, b, bl);
        if (minLight > cc.a && minLight > maxDark) {
            lightestColor = getLargest(cc, lightestColor, br, b, bl);
        }
    }
    
    //Kernel 1 and 5
    maxDark = max3v(cc, l, b);
    minLight = min3v(r, t, tr);
    
    if (minLight > maxDark) {
        lightestColor = getLargest(cc, lightestColor, r, t, tr);
    } else {
        maxDark = max3v(cc, r, t);
        minLight = min3v(bl, l, b);
        if (minLight > maxDark) {
            lightestColor = getLargest(cc, lightestColor, bl, l, b);
        }
    }
    
    //Kernel 2 and 6
    maxDark = max3v(l, tl, bl);
    minLight = min3v(r, br, tr);
    
    if (minLight > cc.a && minLight > maxDark) {
        lightestColor = getLargest(cc, lightestColor, r, br, tr);
    } else {
        maxDark = max3v(r, br, tr);
        minLight = min3v(l, tl, bl);
        if (minLight > cc.a && minLight > maxDark) {
            lightestColor = getLargest(cc, lightestColor, l, tl, bl);
        }
    }
    
    //Kernel 3 and 7
    maxDark = max3v(cc, l, t);
    minLight = min3v(r, br, b);
    
    if (minLight > maxDark) {
        lightestColor = getLargest(cc, lightestColor, r, br, b);
    } else {
        maxDark = max3v(cc, r, b);
        minLight = min3v(t, l, tl);
        if (minLight > maxDark) {
            lightestColor = getLargest(cc, lightestColor, t, l, tl);
        }
    }
    
    
    return lightestColor;
}

kernel void ThinLines(texture2d<float, access::sample> hooked  [[texture(0)]],
                      texture2d<float, access::sample> luma [[texture(1)]],
                      texture2d<float, access::sample> lumag [[texture(2)]],
                      texture2d<float, access::write> scaled [[texture(3)]],
                      sampler smp [[ sampler(0) ]],
                      uint2 gid [[thread_position_in_grid]]) {
    float2 pos = float2(gid) / destination_size;
    scaled.write(hookThinLines(hooked, luma, lumag, smp, pos), gid);
}


//!DESC Anime4K-Refine-v1.0RC2
//!HOOK SCALED
//!BIND HOOKED
//!WHEN OUTPUT.w LUMA.w / 1.400 > OUTPUT.h LUMA.h / 1.400 > *
//!BIND LUMA
//!BIND LUMAD
//!BIND LUMAG

#define LINE_DETECT_MUL 6.0f
#define MAX_STRENGTH 1.0f

#define strength (min((SCALED_size.x) / (LUMA_size.x), 1.0f))
#define lineprob (LUMAG_tex(HOOKED_pos).x)

vec4 getRGBLD(vec2 pos,
              texture2d<float, access::sample> hooked,
              texture2d<float, access::sample> lumad,
              sampler smp) {
    return vec4(HOOKED_tex(pos).rgb, LUMAD_tex(pos).x);
}

vec4 getAverage(vec4 cc, vec4 a, vec4 b, vec4 c,
                texture2d<float, access::sample> lumag,
                sampler smp,
                vec2 pos) {
    float realstrength = clamp(strength * lineprob * LINE_DETECT_MUL, 0.0f, MAX_STRENGTH);
    return cc * (1 - realstrength) + ((a + b + c) / 3) * realstrength;
}


vec4 hookRefine(texture2d<float, access::sample> hooked,
                texture2d<float, access::sample> luma,
                texture2d<float, access::sample> lumag,
                texture2d<float, access::sample> lumad,
                sampler smp,
                vec2 pos)  {

    if (lineprob < LINE_DETECT_THRESHOLD) {
        return HOOKED_tex(HOOKED_pos);
    }

    vec2 d = HOOKED_pt;
    
    vec4 cc = getRGBLD(HOOKED_pos, hooked, lumad, smp);
    vec4 t = getRGBLD(HOOKED_pos + vec2(0, -d.y), hooked, lumad, smp);
    vec4 tl = getRGBLD(HOOKED_pos + vec2(-d.x, -d.y), hooked, lumad, smp);
    vec4 tr = getRGBLD(HOOKED_pos + vec2(d.x, -d.y), hooked, lumad, smp);
    
    vec4 l = getRGBLD(HOOKED_pos + vec2(-d.x, 0), hooked, lumad, smp);
    vec4 r = getRGBLD(HOOKED_pos + vec2(d.x, 0), hooked, lumad, smp);
    
    vec4 b = getRGBLD(HOOKED_pos + vec2(0, d.y), hooked, lumad, smp);
    vec4 bl = getRGBLD(HOOKED_pos + vec2(-d.x, d.y), hooked, lumad, smp);
    vec4 br = getRGBLD(HOOKED_pos + vec2(d.x, d.y), hooked, lumad, smp);
    
    //Kernel 0 and 4
    float maxDark = max3v(br, b, bl);
    float minLight = min3v(tl, t, tr);
    
    if (minLight > cc.a && minLight > maxDark) {
        return getAverage(cc, tl, t, tr, lumag, smp, pos);
    } else {
        maxDark = max3v(tl, t, tr);
        minLight = min3v(br, b, bl);
        if (minLight > cc.a && minLight > maxDark) {
            return getAverage(cc, br, b, bl, lumag, smp, pos);
        }
    }
    
    //Kernel 1 and 5
    maxDark = max3v(cc, l, b);
    minLight = min3v(r, t, tr);
    
    if (minLight > maxDark) {
        return getAverage(cc, r, t, tr, lumag, smp, pos);
    } else {
        maxDark = max3v(cc, r, t);
        minLight = min3v(bl, l, b);
        if (minLight > maxDark) {
            return getAverage(cc, bl, l, b, lumag, smp, pos);
        }
    }
    
    //Kernel 2 and 6
    maxDark = max3v(l, tl, bl);
    minLight = min3v(r, br, tr);
    
    if (minLight > cc.a && minLight > maxDark) {
        return getAverage(cc, r, br, tr, lumag, smp, pos);
    } else {
        maxDark = max3v(r, br, tr);
        minLight = min3v(l, tl, bl);
        if (minLight > cc.a && minLight > maxDark) {
            return getAverage(cc, l, tl, bl, lumag, smp, pos);
        }
    }
    
    //Kernel 3 and 7
    maxDark = max3v(cc, l, t);
    minLight = min3v(r, br, b);
    
    if (minLight > maxDark) {
        return getAverage(cc, r, br, b, lumag, smp, pos);
    } else {
        maxDark = max3v(cc, r, b);
        minLight = min3v(t, l, tl);
        if (minLight > maxDark) {
            return getAverage(cc, t, l, tl, lumag, smp, pos);
        }
    }
    
    
    return cc;
}

kernel void Refine(texture2d<float, access::sample> hooked  [[texture(0)]],
                      texture2d<float, access::sample> luma [[texture(1)]],
                      texture2d<float, access::sample> lumag [[texture(2)]],
                      texture2d<float, access::sample> lumad [[texture(3)]],
                      texture2d<float, access::write> scaled [[texture(4)]],
                      sampler smp [[ sampler(0) ]],
                      uint2 gid [[thread_position_in_grid]]) {
    float2 pos = float2(gid) / destination_size;
    scaled.write(hookRefine(hooked, luma, lumag, lumad, smp, pos), gid);
}


//Fast FXAA (1 Iteration) courtesy of Geeks3D
//https://www.geeks3d.com/20110405/fxaa-fast-approximate-anti-aliasing-demo-glsl-opengl-test-radeon-geforce/3/

//!DESC Anime4K-PostFXAA-v1.0RC2
//!HOOK SCALED
//!BIND HOOKED
//!WHEN OUTPUT.w LUMA.w / 1.400 > OUTPUT.h LUMA.h / 1.400 > *
//!BIND LUMA
//!BIND LUMAG

#define FXAA_MIN (1.0 / 128.0)
#define FXAA_MUL (1.0 / 8.0)
#define FXAA_SPAN 8.0

#define lineprob (LUMAG_tex(HOOKED_pos).x)

vec4 getAverage(vec4 cc, vec4 xc,
                texture2d<float, access::sample> lumag,
                sampler smp,
                vec2 pos) {
    float prob = clamp(lineprob, 0.0f, 1.0f);
    if (prob < LINE_DETECT_THRESHOLD) {
        prob = 0;
    }
    float realstrength = clamp(strength * prob * LINE_DETECT_MUL, 0.0f, 1.0f);
    return cc * (1 - realstrength) + xc * realstrength;
}

vec4 hookPostFXAA(texture2d<float, access::sample> hooked,
                  texture2d<float, access::sample> lumag,
                  sampler smp,
                  vec2 pos)  {

    if (lineprob < LINE_DETECT_THRESHOLD) {
        return HOOKED_tex(HOOKED_pos);
    }


    vec2 d = HOOKED_pt;
    
    
    vec4 cc = HOOKED_tex(HOOKED_pos);
    vec4 xc = cc;
    
//    float t = HOOKED_tex(HOOKED_pos + vec2(0, -d.y)).x;
//    float l = HOOKED_tex(HOOKED_pos + vec2(-d.x, 0)).x;
//    float r = HOOKED_tex(HOOKED_pos + vec2(d.x, 0)).x;
//    float b = HOOKED_tex(HOOKED_pos + vec2(0, d.y)).x;
    
    float tl = HOOKED_tex(HOOKED_pos + vec2(-d.x, -d.y)).x;
    float tr = HOOKED_tex(HOOKED_pos + vec2(d.x, -d.y)).x;
    float bl = HOOKED_tex(HOOKED_pos + vec2(-d.x, d.y)).x;
    float br = HOOKED_tex(HOOKED_pos + vec2(d.x, d.y)).x;
    float cl  = HOOKED_tex(HOOKED_pos).x;
    
    float minl = min(cl, min(min(tl, tr), min(bl, br)));
    float maxl = max(cl, max(max(tl, tr), max(bl, br)));
    
    vec2 dir = vec2(- tl - tr + bl + br, tl - tr + bl - br);
    
    float dirReduce = max((tl + tr + bl + br) *
                          (0.25 * FXAA_MUL), FXAA_MIN);
    
    float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
    dir = min(vec2(FXAA_SPAN, FXAA_SPAN),
              max(vec2(-FXAA_SPAN, -FXAA_SPAN),
              dir * rcpDirMin)) * d;
    
    vec4 rgbA = 0.5 * (
        HOOKED_tex(HOOKED_pos + dir * -(1.0/6.0)) +
        HOOKED_tex(HOOKED_pos + dir * (1.0/6.0)));
    vec4 rgbB = rgbA * 0.5 + 0.25 * (
        HOOKED_tex(HOOKED_pos + dir * -0.5) +
        HOOKED_tex(HOOKED_pos + dir * 0.5));

        
    float lumb = getLum(rgbB);
    
    if ((lumb < minl) || (lumb > maxl)) {
        xc = rgbA;
    } else {
        xc = rgbB;
    }
    return getAverage(cc, xc, lumag, smp, pos);
}

kernel void PostFXAA(texture2d<float, access::sample> hooked  [[texture(0)]],
                      texture2d<float, access::sample> lumag [[texture(1)]],
                      texture2d<float, access::write> scaled [[texture(2)]],
                      sampler smp [[ sampler(0) ]],
                      uint2 gid [[thread_position_in_grid]]) {
    float2 pos = float2(gid) / destination_size;
    float4 out_color = hookPostFXAA(hooked, lumag, smp, pos);
    out_color.a = 1;
    scaled.write(out_color, gid);
}
