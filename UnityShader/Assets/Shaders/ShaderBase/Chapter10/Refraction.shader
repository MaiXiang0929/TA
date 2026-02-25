Shader "Custom/ShaderBase/Chapter10/Refraction"
{
    Properties
    {
        _Color ("Color Tint", Color) = (1,1,1,1)
        _RefractionColor ("Refraction Color", Color) = (1,1,1,1)
        _RefractionAmount ("Refraction Amount", Range(0, 1)) = 1
        _RefractionRatio ("Refraction Ratio", Range(0.1, 1)) = 0.5
        _Cubemap ("Refraction Cubemap", Cube) = "_Skybox" {}
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "Queue"="Geometry"}

        Pass {
            Tags {"LightMode"="ForwardBase"}

            CGPROGRAM

            #pragma multi_compile_fwdbase

            #pragma vertex vert
            #pragma fragment frag

            #include "Lighting.cginc"
            #include "AutoLight.cginc"

            fixed4 _Color;
            fixed4 _RefractionColor;
            float _RefractionAmount;
            fixed _RefractionRatio;
            samplerCUBE _Cubemap;

            struct a2v {
                float4 vertex : POSITION;
				float3 normal : NORMAL;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                float3 worldViewDir : TEXCOORD2;
                float3 worldRefr : TEXCOORD3;
                SHADOW_COORDS(4)
            };

            v2f vert(a2v v) {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);

                o.worldNormal = UnityObjectToWorldNormal(v.normal);

                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;

                o.worldViewDir = UnityWorldSpaceViewDir(o.worldPos);

                // compute the refract dir in world space
                o.worldRefr = refract(-normalize(o.worldViewDir), normalize(o.worldNormal), _RefractionRatio);

                TRANSFER_SHADOW(o);

                return o;
            }

            fixed4 frag(v2f i) : SV_Target {
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                fixed3 worldViewDir = normalize(i.worldViewDir);

                fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                fixed3 diffuse = _LightColor0.rgb * _Color.rgb * max(0, dot(worldNormal, worldLightDir));

                // use the refract dir in world space to access the cubemap
                fixed3 refraction = texCUBE(_Cubemap, i.worldRefr).rgb * _RefractionColor.rgb;

                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

                // mix the diffuse color with the refract color
                fixed3 color = ambient + lerp(diffuse, refraction, _RefractionAmount) * atten;
                
                return fixed4(color, 1.0);
            }

            ENDCG
            
        }
    }
    FallBack "Reflective/VertexLit"
}
