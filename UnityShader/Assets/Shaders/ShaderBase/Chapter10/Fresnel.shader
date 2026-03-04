Shader "Custom/ShaderBase/Chapter10/Fresnel"
{
    Properties
    {
        [Header(Base Settings)]
        _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
        _FresnelScale ("Fresnel Scale", Range(0, 1)) = 0.5

        [Header(Skybox Settings)]
        [NoScaleOffset] _Cubemap ("Refraction Cubemap", Cube) = "_Skybox" {}

        [Header(Box Projection Settings)]
        [Vector3] _BoxCenter ("Room Center (World)", Vector) = (0, 0, 0, 0)
        [Vector3] _BoxMin ("Room Min (World)", Vector) = (-5, -5, -5, 0)
        [Vector3] _BoxMax ("Room Max (World)", Vector) = (5, 5, 5, 0)
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue"="Geometry"
        }

        HLSLINCLUDE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _FresnelScale;
                float3 _BoxCenter;
                float3 _BoxMin;
                float3 _BoxMax;
            CBUFFER_END

            TEXTURECUBE(_Cubemap);
            SAMPLER(sampler_Cubemap);

        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags {"LightMode" = "UniversalForward"}

            HLSLPROGRAM

                // #pragma multi_compile_forwardplus // 启用 Forward+ 渲染路径，支持多光源优化及多反射探针混合
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS // 主光源阴影开关
                #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE // 主光源级联阴影开关
                #pragma multi_compile _ _SHADOWS_SOFT // 阴影平滑开关

                #pragma vertex vert
                #pragma fragment frag

                struct Attributes
                {
                    float4 positionOS : POSITION;
                    float3 normalOS : NORMAL;
                };

                struct Varyings
                {
                    float4 positionCS : SV_POSITION;
                    float3 positionWS : TEXCOORD0;
                    float3 normalWS : TEXCOORD1;
                };

                Varyings vert(Attributes input)
                {
                    Varyings output = (Varyings)0;
                    
                    // position
                    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                    output.positionCS = vertexInput.positionCS;
                    output.positionWS = vertexInput.positionWS;
                    
                    // normal
                    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
                    output.normalWS = normalInput.normalWS;
                    
                    return output;
                }

                half4 frag(Varyings input) : SV_Target
                {
                    // Light Info
                    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                    Light mainLight = GetMainLight(shadowCoord);
                    half3 lightColor = mainLight.color;
                    half3 lightDirWS = mainLight.direction;
                    half shadowAttenuation = mainLight.shadowAttenuation;

                    // Normalize Vector
                    half3 normalWS = normalize(input.normalWS);
                    half3 viewDirWS = normalize(GetWorldSpaceViewDir(input.positionWS));
                    half3 reflectDirWS = reflect(-viewDirWS, normalWS);

                    // Ambient
                    half3 ambient = SampleSH(normalWS);

                    // Reflection
                    // Box Projection
                    float3 factorsMax = (_BoxMax - input.positionWS) / reflectDirWS;
                    float3 factorsMin = (_BoxMin - input.positionWS) / reflectDirWS;
                    float3 selection = (reflectDirWS > 0) ? factorsMax : factorsMin; // 选取射线朝向方向的那个交点

                    float distance = min(min(selection.x, selection.y), selection.z); // 找到最近的交点距离
                   
                    float3 intersectPositionWS = input.positionWS + reflectDirWS * distance; // 计算交点在世界空间的位置
                    
                    half3 correctedDir = intersectPositionWS - _BoxCenter; // 计算从盒子中心到交点的方向，这是修正后的采样方向

                    half3 reflection = SAMPLE_TEXTURECUBE(_Cubemap, sampler_Cubemap, correctedDir).rgb;

                    // Fresnel
                    half fresnel = _FresnelScale + (1 - _FresnelScale) * pow(1 - dot(viewDirWS, normalWS), 5);

                    // Diffuse
                    half diff = saturate(dot(normalWS, lightDirWS));
                    half3 diffuse = lightColor * _BaseColor.rgb * diff;

                    // Merge Colr
                    half3 finalColor = ambient + lerp(diffuse, reflection, saturate(fresnel)) * shadowAttenuation;

                    return half4(finalColor, 1.0);
                }

            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    //项目中用
    //FallBack "Universal Render Pipeline/Lit"
}
