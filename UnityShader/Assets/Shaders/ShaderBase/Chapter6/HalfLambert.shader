Shader "Custom/ShaderBase/Chapter6/HalfLambert"
{
    Properties
    {
        _Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
        }

        HLSLINCLUDE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)

                float4 _Diffuse;

            CBUFFER_END

        ENDHLSL

        Pass 
        {
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
        
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
                float3 normalWS : TEXCOORD0;
            };

            Varyings vert(Attributes input) {
                Varyings output;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);

                return output;
            }

            half4 frag(Varyings input) : SV_Target 
            {
                half3 ambient = SampleSH(input.normalWS);
                half3 normalWS = normalize(input.normalWS);

                Light mainLight = GetMainLight();
                half3 lightColor = mainLight.color;
                half3 lightDirWS = normalize(mainLight.direction);

                
                half halfLambert = dot(normalWS, lightDirWS) * 0.5 + 0.5;
                half3 diffuse = lightColor * _Diffuse.rgb * halfLambert;

                half3 finalColor = ambient + diffuse;

                return float4(finalColor, 1.0);
            }

            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Simple Lit"
}
