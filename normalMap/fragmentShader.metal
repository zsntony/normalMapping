//
//  Untitled.metal
//  normalMap
//
//  Created by Tony on 2025/4/16.
//

// 完整Shader代码（包含顶点/片段着色器）
#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float2 position [[attribute(0)]];
    float2 texCoord [[attribute(1)]];
};

struct VertexOut {
    float4 position [[position]];
    float2 texCoord;
};

vertex VertexOut vertexShader(
    VertexIn in [[stage_in]],
    constant float4x4 &mvpMatrix [[buffer(1)]]
) {
    VertexOut out;
    out.position = mvpMatrix * float4(in.position, 0, 1);
    out.texCoord = in.texCoord;
    return out;
}

fragment float4 fragmentShader(
    VertexOut in [[stage_in]],
    texture2d<float> baseTexture [[texture(0)]],
    texture2d<float> normalTexture [[texture(1)]],
    device float3 &lightDirection [[buffer(0)]]
) {
    constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
    
    // 采样原图和法线贴图
    float3 baseColor = baseTexture.sample(textureSampler, in.texCoord).rgb;
    float3 normal = normalTexture.sample(textureSampler, in.texCoord).rgb;
    
    // 法线向量转换（0-1转-1到1）
    normal = normalize(normal * 2.0 - 1.0);
    
    // 计算漫反射强度
    float3 L = normalize(lightDirection);
    float diffuse = max(dot(normal, L), 0.0);
    
    // 计算镜面反射（Phong模型）[9,10](@ref)
    float3 V = float3(0, 0, 1); // 假设视线垂直屏幕
    float3 R = reflect(-L, normal);
    float specular = pow(max(dot(R, V), 0.0), 32.0);
    
    // 合成最终颜色
    float3 finalColor = baseColor * diffuse + float3(1.0) * specular * 0.5;
    return float4(finalColor, 1.0);
}
