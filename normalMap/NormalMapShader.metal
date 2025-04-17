//
//  NormalMapShader.metal
//  normalMap
//
//  Created by Tony on 2025/4/16.
//

#include <metal_stdlib>
using namespace metal;

kernel void normalMapKernel(
    texture2d<float, access::sample> inTexture [[ texture(0) ]],
    texture2d<float, access::write> outTexture [[ texture(1) ]],
    uint2 gid [[ thread_position_in_grid ]]
) {
    if (gid.x >= inTexture.get_width() || gid.y >= inTexture.get_height()) {
        return;
    }
    
    constexpr sampler textureSampler(filter::linear, address::clamp_to_edge);
    
    // 读取输入灰度值（假设输入是一张单通道灰度纹理，将其放到 float 变量中）
    float intensity = inTexture.sample(textureSampler, float2(gid) / float2(inTexture.get_width(), inTexture.get_height())).r;
    
    // 使用 Sobel 算子计算梯度
    // 定义 Sobel 卷积核
    float kernelX[3][3] = { { -1, 0, 1 },
                            { -2, 0, 2 },
                            { -1, 0, 1 } };
    float kernelY[3][3] = { { -1, -2, -1 },
                            {  0,  0,  0 },
                            {  1,  2,  1 } };
    
    float dx = 0.0;
    float dy = 0.0;
    float2 texSize = float2(inTexture.get_width(), inTexture.get_height());
    float2 step = 1.0 / texSize;
    
    // 对于简单处理，读取周围 3x3 像素进行卷积
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            float2 coord = (float2(gid) + float2(i, j)) * step;
            float sample = inTexture.sample(textureSampler, coord).r;
            dx += sample * kernelX[j + 1][i + 1];
            dy += sample * kernelY[j + 1][i + 1];
        }
    }
    
    // 应用一个强度因子（可根据需求调整）
    float factor = 0.75;
    dx *= factor;
    dy *= factor;
    
    // 计算 z 分量：确保单位向量（x² + y² + z² = 1）
    float z = sqrt(max(1.0 - dx*dx - dy*dy, 0.0));
    
    float3 normal = normalize(float3(-dx, -dy, z));
    // 将 [-1,1] 映射到 [0,1]
    float3 color = (normal + 1.0) * 0.5;
    
    outTexture.write(float4(color, 1.0), gid);
}
