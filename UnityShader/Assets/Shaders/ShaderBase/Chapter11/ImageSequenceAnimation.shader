Shader "Custom/ShaderBase/Chapter11/ImageSequenceAnimation"
{
    Properties
    {
        _Color ("Color", Color) = (1,1,1,1)
        _BaseMap ("Albedo (RGB)", 2D) = "white" {}
        _HorizontalAmount ("Horizontal Amount", Float) = 4
        _VerticalAmount ("Vertical Amount", Float) = 4
        _Speed ("Speed", Range(0, 100)) = 30
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

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseMap_ST;
                float4 _Color;
                float _HorizontalAmount;
                float _VerticalAmount;
                float _Speed;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_linear_repeat);
        ENDHLSL
        
        Pass
        {
            Tags{ "LightMode" = "UniversalForward" }

            ZWrite Off
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM

                #pragma vertex vert;
                #pragma fragment frag;

                struct Attributes
                {
                    float4 positionOS : POSITION;
                    float2 uv : TEXCOORD0;
                };

                struct Varyings
                {
                    float4 positionCS : SV_POSITION;
                    float2 uv : TEXCOORD0; 
                };

                Varyings vert(Attributes input)
                {
                    Varyings output = (Varyings)0;

                    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

                    return output;
                }

                half4 frag(Varyings input) : SV_Target
                {
                    // 计算总时间及当前帧索引
                    float time = floor(_Time.y * _Speed);
                    float row = floor(time / _HorizontalAmount);
                    float column = fmod(time, _HorizontalAmount);

                    // 缩放UV
                    half2 uv = input.uv;
                    uv.x /= _HorizontalAmount;
                    uv.y /= _VerticalAmount;

                    // 偏移UV到正确的帧位置
                    //序列帧通常从左上角开始
                    uv.x += column / _HorizontalAmount;
                    uv.y -= row / _VerticalAmount;

                    half4 c = SAMPLE_TEXTURE2D(_BaseMap, sampler_linear_repeat, uv);
                    c.rgb *= _Color;

                    return c;
                }

            ENDHLSL
        }
    }
    Fallback "Hidden/Universal Render Pipeline/FallbackError"
    // Fallback "Unlit/Texture"
}
