Shader "Custom/ShaderBase/Chapter7/RampTexture"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _RampTex ("Ramp Texture", 2D) = "white" {}
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }

        HLSLINCLUDE // 公共代码块

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)

                float4 _BaseColor;
                float4 _RampTex_ST;
                float4 _SpecularColor;
                float _Gloss;

            CBUFFER_END

            // 定义纹理和采样器
            TEXTURE2D(_RampTex);
            SAMPLER(sampler_RampTex);

        ENDHLSL // 公共代码块结束

        Pass
        {
            Name "ForwardLit"
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

                    // uv
                    output.uv = TRANSFORM_TEX(input.uv, _RampTex);

                    return output;
                }

                half4 frag(Varyings input) : SV_Target
                {
                    // Light Info
                    Light mainLight = GetMainLight();
                    half3 lightDirWS = normalize(mainLight.direction);
                    half3 lightColor = mainLight.color;

                    // Normalize Vector
                    half3 normalWS = normalize(input.normalWS);
                    half3 viewDirWS = normalize(GetWorldSpaceViewDir(input.positionWS));

                    // Ambient
                    half3 ambient = SampleSH(normalWS);

                    // Diffuse
                    half halfLambert = dot(normalWS, lightDirWS) * 0.5 + 0.5;
                    half3 rampColor = SAMPLE_TEXTURE2D(_RampTex, sampler_RampTex, float2(halfLambert, 0.5)).rgb;
                    half3 diffuse = rampColor * _BaseColor.rgb * lightColor;

                    // Blinn-Phong Specular
                    half3 halfDirWS = normalize(lightDirWS + viewDirWS);
                    float spec = pow(max(0, dot(normalWS, viewDirWS)), _Gloss);
                    half3 specular = _SpecularColor.rgb * spec * lightColor;

                    // Merge Color
                    half3 finalColor = ambient * _BaseColor.rgb + diffuse + specular;

                    return half4(finalColor, 1.0);
                }

            ENDHLSL
        }
        
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    //项目中用
    //FallBack "Universal Render Pipeline/Lit"
}
