Shader "Custom/ShaderBase/Chapter8/AlphaBlendBothSided"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _BaseMap ("Base Map", 2D) = "white" {}
        _AlphaScale ("Alpha Scale", Range(0, 1)) = 1
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"            
        }

        HLSLINCLUDE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)

                float4 _BaseColor;
                float4 _BaseMap_ST;
                float _AlphaScale;

            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

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
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // Light Info
                Light mainLight = GetMainLight(); 
                half3 lightDirWS = normalize(mainLight.direction);
                half3 lightColor = mainLight.color;

                // Texture Info
                half4  baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);

                // Normalize Vector
                half3 normalWS = normalize(input.normalWS);

                // Albedo
                half4 albedo = baseMap * _BaseColor;

                // Ambient
                half3 ambient = SampleSH(normalWS) * albedo.rgb;

                // Diffuse
                float diff = max(0, dot(normalWS, lightDirWS));
                half3 diffuse = lightColor * albedo.rgb * diff; 
                
                // Merge Color
                half3 finalColor = ambient + diffuse;

                return half4(finalColor, baseMap.a * _AlphaScale);
            }

        ENDHLSL
        
        Pass
        {
            Name "BackFace"
            // Tags { "LightMode"="UniversalForward" }

            Cull Front // 剔除正面

            ZWrite off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM

                #pragma vertex vert
                #pragma fragment frag
      
            ENDHLSL
        }

        Pass
        {
            Name "FrontFace"
            Tags { "LightMode"="UniversalForward" }

            Cull Back // 剔除反面

            ZWrite off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM

                #pragma vertex vert
                #pragma fragment frag
      
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    //项目中用
    //FallBack "Universal Render Pipeline/Lit"
}
