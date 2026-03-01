// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/ShaderBase/Chapter7/SingleTexture"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1,1,1,1)
        _MainTex ("Main Tex", 2D) = "white" {}
        _Specular ("Specular", Color) = (1,1,1,1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
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
                float4 _Color;
                sampler2D _MainTex;
                float4 _MainTex_ST;
                float4 _Specular;
                float _Gloss;
            CBUFFER_END

        ENDHLSL

        Pass
        {
            Tags {"LightMode" = "UniversalForward"}

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            Varyings vert(Attributes input){
                Varyings output;

                VertexPositionInputs posInputs = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = posInputs.positionCS;
                output.positionWS = posInputs.positionWS;
                
                // 法线变换到世界空间
                VertexNormalInputs normalInputs = GetVertexNormalInputs(input.normalOS);
                output.normalWS = normalInputs.normalWS;
                
                // UV 变换
                output.uv = input.uv;

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                Light mainLight = GetMainLight();
                half3 lightColor = mainLight.color;

                half3 normalWS = normalize(input.normalWS);
                half3 lightDirWS = normalize(mainLight.direction);

                half4 mainTex = tex2D(_MainTex, input.uv);

                half3 albedo = mainTex.rgb * _Color.rgb;

                half3 ambient = unity_AmbientSky.rgb * albedo;

                half3 diffuse = lightColor * albedo * max(0, dot(normalWS,lightDirWS));

                half3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                half3 halfDir = normalize(lightDirWS + viewDirWS);
                half3 specular = lightColor * _Specular.rgb * pow(max(0, dot(normalWS, halfDir)), _Gloss);

                half3 finalColor = ambient + diffuse + specular;

                return half4(finalColor, 1.0);
            }

            ENDHLSL
        }
    }
    FallBack "Universal Render Pipeline/Lit"
}
