Shader "Custom/ShaderBase/Chapter7/MaskTexture"
{
    Properties
    {
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _BaseMap ("Base Map", 2D) = "white" {}
        _BumpMap ("Normal Map", 2D) = "bump" {}
        _BumpScale ("Bump Scale", Float) = 1.0
        _SpecularMask ("Specular Mask", 2D) = "white" {}
        _SpecularScale ("Specular Scale", Float) = 1.0
        _SpecularColor ("Specular Color", Color) = (1,1,1,1)
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

                float4 _BaseColor;
                float4 _BaseMap_ST;
                float _BumpScale;
                float _SpecularScale;
                float4 _SpecularColor;
                float _Gloss;

            CBUFFER_END

            // 定义纹理和采样器
            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_BumpMap);
            SAMPLER(sampler_BumpMap);
            TEXTURE2D(_SpecularMask);
            SAMPLER(sampler_SpecularMask);

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
                    float2 uv : TEXCOORD0;
                    float3 tangentWS : TEXCOORD1;
                    float3 bitangentWS : TEXCOORD2;
                    float3 normalWS : TEXCOORD3;
                    float3 positionWS : TEXCOORD4;
                };

                Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                
                // position
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.positionWS = vertexInput.positionWS;

                // UV
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

                // TBN Vector
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = normalInput.normalWS;
                output.tangentWS = normalInput.tangentWS;
                output.bitangentWS = normalInput.bitangentWS;

                return output;
            }

            half4 frag(Varyings input) : SV_TARGET
            {
                // 获取基础纹理颜色
                half4 albedo = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;

                // 解码法线并从切线空间转换到世界空间
                half3 normalTS = UnpackNormalScale(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, input.uv), _BumpScale);

                float3x3 tangentToWorld = float3x3(input.tangentWS, input.bitangentWS, input.normalWS);
                half3 normalWS = normalize(mul(normalTS, tangentToWorld));

                // 获取主光源信息
                Light mainLight = GetMainLight();
                half3 lightDirWS = normalize(mainLight.direction);
                half3 viewDirWS = normalize(GetWorldSpaceViewDir(input.positionWS));
                half3 halfDirWS = normalize(lightDirWS + viewDirWS);

                // 计算光照(Blinn-Phong)
                // ambient
                half3 ambient = SampleSH(normalWS) * albedo.rgb;

                // diffuse
                float diff = max(0, dot(normalWS, lightDirWS));
                half3 diffuse = mainLight.color * albedo.rgb * diff;

                // specular
                float spec = pow(max(0, dot(normalWS, halfDirWS)), _Gloss);
                half3 specular = mainLight.color * _SpecularColor.rgb * spec;

                // finalColor
                half3 finalColor = ambient + diffuse + specular;

                return half4(finalColor, albedo.a);
            }

            ENDHLSL
        }
    //    Pass{
    //        v2f vert(a2v v){
    //            v2f o;
    //            o.pos = UnityObjectToClipPos(v.vertex);
    //            o.uv.xy = v.texcoord.xy * _MainTex_ST.xy +_MainTex_ST.zw;

    //            TANGENT_SPACE_ROTATION;
    //            // transform the light direction from object space to tangent space
    //            o.lightDir = mul(rotation, ObjSpaceLightDir(v.vertex)).xyz;
    //            // transform the view direction from object space to tangent space
    //            o.viewDir = mul(rotation, ObjSpaceViewDir(v.vertex)).xyz;

    //            return o;
    //        }

    //        fixed4 frag(v2f i) : SV_Target{
    //            fixed3 tangentLightDir = normalize(i.lightDir);
    //            fixed3 tangentViewDir = normalize(i.viewDir);

    //            fixed3 tangentNormal = UnpackNormal(tex2D(_BumpMap, i.uv));
    //            tangentNormal.xy *= _BumpScale;
    //            tangentNormal.z = sqrt(1.0 - saturate(dot(tangentNormal.xy, tangentNormal.xy)));

    //            fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
    //            fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

    //            fixed3 diffuse = _LightColor0.rgb * albedo * max(0, dot(tangentNormal, tangentLightDir));

    //            fixed3 halfDir = normalize(tangentLightDir + tangentViewDir);
    //            // get the mask value
    //            fixed3 specularMask = tex2D(_SpecularMask, i.uv).r * _SpecularScale;
    //            // compute specular term with the specular mask
    //            fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0, dot(tangentNormal, halfDir)), _Gloss) * specularMask;

    //            return fixed4(ambient + diffuse + specular, 1.0);

    //        }
    //        ENDCG
    //    }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    //项目中用
    //FallBack "Universal Render Pipeline/Lit"
}
