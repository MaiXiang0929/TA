Shader "Custom/ShaderBase/Chapter7/NormalMapTangentSpace"
// 在切线空间下进行光照计算适用于单光源、特殊效果，与URP契合度较低
{
    Properties
    {
        _BaseMap ("Base Map", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        [Normal] _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1.0
        _SpecularColor ("Specular", Color) = (1,1,1,1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Tags
        {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
            "UniversalMaterialType" = "Lit"
        }

        HLSLINCLUDE

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
                
                float4 _BaseMap_ST;
                float4 _BumpMap_ST;
                half4 _BaseColor;
                half4 _SpecularColor;
                float _BumpScale;
                float _Gloss;

            CBUFFER_END

            TEXTURE2D(_BaseMap);    SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);    SAMPLER(sampler_BumpMap);

        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags{"LightMode" = "UniversalForward"}

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float4 uv : TEXCOORD0;
                float3 lightDirTS : TEXCOORD1;
                float3 viewDirTS : TEXCOORD2;
            };

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS);
                output.positionCS = vertexInput.positionCS;

                output.uv.xy = input.uv.xy * _BaseMap_ST.xy +_BaseMap_ST.zw;

                output.uv.zw = input.uv.xy * _BumpMap_ST.xy +_BumpMap_ST.zw;

                float3 normalOS = input.normalOS;
                float3 tangentOS = input.tangentOS.xyz;
                float3 bitangentOS = cross(normalOS, tangentOS) * input.tangentOS.w;

                float3x3 objectToTangent = float3x3(tangentOS, bitangentOS, normalOS);

                Light mainLight = GetMainLight();
                float3 lightDirWS = normalize(mainLight.direction);
                float3 lightDirOS = TransformWorldToObjectDir(lightDirWS);
                output.lightDirTS = normalize(mul(objectToTangent, lightDirOS));

                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(vertexInput.positionWS);
                float3 viewDirOS = TransformWorldToObjectDir(viewDirWS);
                output.viewDirTS = normalize(mul(objectToTangent, viewDirOS));

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                // 获取主光源信息
                Light mainLight = GetMainLight();

                // 归一化方向向量
                half3 LightDirTS = normalize(input.lightDirTS);
                half3 ViewDirTS = normalize(input.viewDirTS);
                half3 halfDirTS = normalize(LightDirTS + ViewDirTS);

                // 获取基础纹理颜色
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv.xy) * _BaseColor;

                // 采样解码法线贴图
                half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv.zw), _BumpScale);

                // ambient 暂时使用 URP 全局环境光或固定值
                half3 ambient = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w) * albedo.rgb;

                // diffuse
                float diff = max(0, dot(normalTS, LightDirTS));
                half3 diffuse = mainLight.color * albedo.rgb * diff;

                // specular
                float spec = pow(max(0, dot(normalTS, halfDirTS)), _Gloss);
                half3 specular = mainLight.color * _SpecularColor.rgb * spec;

                // finalColor
                half3 finalColor = ambient + diffuse + specular;

                return half4(finalColor, albedo.a);
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    //项目中用
    //FallBack "Universal Render Pipeline/Lit"
}
