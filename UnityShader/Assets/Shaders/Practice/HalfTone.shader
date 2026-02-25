Shader "Custom/Practice/HalftoneShader"
{
    Properties
    {
        _MainTex ("Base (RGB)", 2D) = "white" {}
        _DotSize ("Dot Size", Range(0.01, 0.1)) = 0.05
        _DotColor ("Dot Color", Color) = (1, 1, 1, 1)

        // 控制圆半径的参数
        _DotRadiusMultiplier ("Dot Radius Multiplier", Range(0.0, 1.0)) = 1.0
        // 控制dot区域的参数
        _DotAreaThreshold ("Dot Area Threshold", Range(0.2, 10.0)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile _MAIN_LIGHT_SHADOWS // 主光源阴影
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE // 主光源阴影级联
            #pragma multi_compile _MAIN_LIGHT_SHADOWS_SCREEN // 主光源阴影屏幕空间

            #pragma multi_compile_fragment _LIGHT_LAYERS // 光照层
            #pragma multi_compile_fragment _LIGHT_COOKIES // 光照饼干
            #pragma multi_compile_fragment _SCREEN_SPACE_OCCLUSION // 屏幕空间遮挡
            #pragma multi_compile_fragment _ADDITIONAL_LIGHT_SHADOWS // 额外光源阴影
            #pragma multi_compile_fragment _SHADOWS_SOFT // 阴影软化

            
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _DotSize;
            float4 _DotColor;

            float _DotRadiusMultiplier;
            float _DotAreaThreshold;
            
            struct a2v
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
            };

            

            v2f vert (a2v v)
            {
                v2f o;
                o.pos = TransformObjectToHClip(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = TransformObjectToWorldNormal(v.normal);
                o.worldPos = TransformObjectToWorld(v.vertex.xyz);
                return o;
            }

            half4 frag (v2f i) : SV_Target
            {
                // 采样基础纹理颜色
                half4 baseColor = tex2D(_MainTex, i.uv);

                // 将UV坐标按网点大小进行划分
                float2 dotUV = i.uv / _DotSize;
                // 获取每个网点内的相对坐标
                float2 dotPos = frac(dotUV);
                // 网点中心位置
                float2 dotCenter = float2(0.5, 0.5);

                // 通过纹理采样间接获取纹理尺寸
                float2 maxUV = float2(1, 1);
                float2 minUV = float2(0, 0);
                float2 maxTexel = tex2Dlod(_MainTex, float4(maxUV, 0, 0)).xy;
                float2 minTexel = tex2Dlod(_MainTex, float4(minUV, 0, 0)).xy;
                float2 textureSize = abs(maxTexel - minTexel);
                float aspectRatio = textureSize.x / textureSize.y;

                // 修正后的UV坐标
                float2 correctedDotPos = dotPos;
                if (aspectRatio > 1)
                {
                    correctedDotPos.x *= aspectRatio;
                }
                else
                {
                    correctedDotPos.y /= aspectRatio;
                }

                // 计算当前点到网点中心的距离
                float dist = distance(dotPos, dotCenter);

                /// 获取光照信息
                Light mainLight = GetMainLight(TransformWorldToShadowCoord(i.worldPos));
                half halfLambert = dot(i.worldNormal, - mainLight.direction) * 0.5 + 0.5;
                halfLambert = pow(halfLambert, _DotAreaThreshold); // 可以调整指数来控制亮度对网点大小的影响)
                half dotRadius = _DotRadiusMultiplier * baseColor.a * halfLambert;

                half isDot = step(dist, dotRadius);
                half4 finalColor = lerp(baseColor, _DotColor, isDot);

                return finalColor;
            }
            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Lit"
}