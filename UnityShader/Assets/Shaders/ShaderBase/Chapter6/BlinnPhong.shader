Shader "Custom/ShaderBase/Chapter6/BlinnPhong"
{
    Properties
    {
        _Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward"}

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _Diffuse;
                float4 _Specular;
                float _Gloss;
            CBUFFER_END
            
            struct Attributes{
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
            };

            struct Varyings{
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                };

            Varyings vert(Attributes input)
            {
                Varyings output;

                // 将顶点从对象空间变换到裁剪空间
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                
                // 将法线从对象空间变换到世界空间
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                
                // 计算世界空间位置
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                
                return output;
            }

             half4 frag(Varyings input) : SV_Target
            {
                // 环境光
                half3 ambient = unity_AmbientSky.rgb;
                
                // 归一化法线
                half3 normalWS = normalize(input.normalWS);
                
                // 获取主光源信息
                Light mainLight = GetMainLight();
                half3 lightColor = mainLight.color;
                half3 lightDirWS = normalize(mainLight.direction);
                
                // 漫反射 (Lambert)
                half NdotL = saturate(dot(normalWS, lightDirWS));
                half3 diffuse = lightColor * _Diffuse.rgb * NdotL;
                
                // 视线方向
                half3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz - input.positionWS);
                
                // Blinn-Phong高光：halfDir = viewDir + lightDir
                half3 halfDir = normalize(viewDirWS + lightDirWS);
                half specAngle = max(0, dot(normalWS, halfDir));
                half3 specular = lightColor * _Specular.rgb * pow(specAngle, _Gloss);
                
                // 合并光照
                half3 finalColor = ambient + diffuse + specular;
                
                return half4(finalColor, 1.0);
            }

            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Simple Lit"
}
