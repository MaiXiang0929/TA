Shader "Custom/Shadow"
{
    Properties
    {
        _Diffuse ("Diffuse", Color) = (1, 1, 1, 1)
        _Specular ("Specular", Color) = (1, 1, 1, 1)
        _Gloss ("Gloss", Range(8.0, 256)) = 20
    }
    SubShader
    {
        Pass
        {
            // pass for ambient light & first light (directional light)
            Tags {"LightMode" = "ForwardBase"}

            CGPROGRAM
            #pragma multi_compile_fwdbase
            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            fixed4 _Diffuse;
            fixed4 _Specular;
            float _Gloss;

            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f{
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                SHADOW_COORDS(2)
                };

            v2f vert(a2v v){
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                // pass shadow coordinates to pixel shader
                TRANSFER_SHADOW(o);

                return o;
                }

            fixed4 frag(v2f i) : SV_Target{
                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

                // use shadow coordinates to sample shadow map
                fixed shadow = SHADOW_ATTENUATION(i);

                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLightDir));

                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 halfDir = normalize(viewDir + worldLightDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0,dot(worldNormal,halfDir)), _Gloss);

                fixed atten = 1.0;

                return fixed4(ambient + (diffuse + specular) * shadow * atten, 1.0);
                }

            ENDCG
        }

        Pass
        {
            // pass for other pixel lights
            Tags { "LightMode"="ForwardAdd" }

            Blend One One

            CGPROGRAM
            #pragma multi_compile_fwdadd
            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"

            fixed4 _Diffuse;
            fixed4 _Specular;
            float _Gloss;

            struct a2v{
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct v2f{
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                LIGHTING_COORDS(2, 3)
                };

            v2f vert(a2v v){
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                TRANSFER_VERTEX_TO_FRAGMENT(o);

                return o;
                }

            fixed4 frag(v2f i) : SV_Target{

                fixed3 worldNormal = normalize(i.worldNormal);

                #ifdef USING_DIRECTIONAL_LIGHT
                    fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);
                #else
                    fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
                #endif

                fixed3 diffuse = _LightColor0.rgb * _Diffuse.rgb * saturate(dot(worldNormal, worldLightDir));

                fixed3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 halfDir = normalize(viewDir + worldLightDir);
                fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(max(0,dot(worldNormal,halfDir)), _Gloss);

                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                return fixed4( (diffuse + specular) * atten, 1.0);
                }

            ENDCG
        }
    }
    FallBack "Specular"
}
