Shader "Custom/ShaderBase/Chapter10/GlassRefraction"
{
    Properties
    {
        _BaseMap ("Base Map", 2D) = "white" {}
        _BumpMap("Normal Map", 2D) = "bump" {}
        _Cubemap("Environment Cubemap", Cube) = "_Skybox" {}

        _Distortion("Distortion", Range(0, 100)) = 10
        _Reflectivity("Reflectivity", Range(0, 1)) = 0.04
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        HLSLINCLUDE
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float _Distortion;
                float _Reflectivity;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            TEXTURECUBE(_Cubemap);
            SAMPLER(sampler_Cubemap);
            TEXTURE2D(_CameraOpaqueTexture);
            SAMPLER(sampler_CameraOpaqueTexture);
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags {"LightMode" = "UniversalForward"}

            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM
                #pragma vertex vert
                #pragma fragment frag

                struct Attributes
                {
                    float4 positionOS : POSITION;
                    float2 uv : TEXCOORD0;
                    float3 normalOS : NORMAL;
                    float4 tangentOS : TANGENT;
                };

                struct Varyings
                {
                    float4 positionCS : SV_POSITION;
                    float2 uv : TEXCOORD0;
                    float4 screenPos : TEXCOORD1;
                    float3 positionWS : TEXCOORD2;
                    float3 normalWS : TEXCOORD3;
                    float3 tangentWS : TEXCOORD4;
                    float3 bitangentWS : TEXCOORD5;
                };

                Varyings vert(Attributes input)
                {
                    Varyings output = (Varyings)0;

                    // position
                    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                    output.positionWS = vertexInput.positionWS;
                    output.positionCS = vertexInput.positionCS;

                    // uv
                    output.uv = input.uv;

                    // screenpos
                    output.screenPos = ComputeScreenPos(output.positionCS);

                    // normal
                    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                    output.normalWS = normalInput.normalWS;
                    output.tangentWS = normalInput.tangentWS;
                    output.bitangentWS = normalInput.bitangentWS;

                    return output;
                }

                half4 frag(Varyings input) : SV_Target
                {
                    // Textur Info
                    half4 albedoMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                    half4 normalMap = SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv);

                    // Normalize Vector
                    float3 n = normalize(input.normalWS);
                    float3 t = normalize(input.tangentWS);
                    float3 b = normalize(input.bitangentWS);
                    float3x3 TBN = float3x3(t, b, n);

                    half3 normalTS = UnpackNormal(normalMap);
                    half3 normalWS = TransformTangentToWorld(normalTS, TBN);
                    half3 viewDirWS = normalize(GetWorldSpaceViewDir(input.positionWS));

                    // Albedo
                    half3 albedo = albedoMap.rgb;

                    // Refraction
                    
                    float2 screenUV = input.screenPos.xy / input.screenPos.w;

                    float2 offset = normalWS.xy * _Distortion * 0.01; // 使用世界空间法线使折射更真实
                    screenUV += offset;

                    half3 refractColor = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, screenUV).rgb;

                    // Reflection
                    half3 reflectDirWS = reflect(-viewDirWS, normalWS);
                    half3 reflectColor = SAMPLE_TEXTURECUBE(_Cubemap, sampler_Cubemap, reflectDirWS).rgb;

                    // Fresnel
                    float fres = pow(1-saturate(dot(normalWS, viewDirWS)), 5);
                    float fresnel = pow(1 - saturate(dot(viewDirWS, normalWS)), 5); 
                    
                    // Merge Color
                    half3 finalColor = lerp(refractColor, reflectColor, fresnel);
                    
                    return half4(finalColor, albedoMap.a);
                }
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    //项目中用
    //FallBack "Universal Render Pipeline/Unlit"
}
