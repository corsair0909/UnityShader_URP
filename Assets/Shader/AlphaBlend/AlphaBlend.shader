Shader "Unlit/AlphaBlend"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("MainCol",color) = (1,1,1,1)
        _AlphaScale ("AlphaScale",Range(0,1)) = 0.1
    }
    SubShader
    {
        Tags { 
                "RenderPipeLine"="UniversalRenderPipeLine"
                "IgnoreProjector"="True"
                "RenderType"="Transparent"
                "Queue"="Transparent"
            }   
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        CBUFFER_START(UnityProperties)
        float4 _MainTex_ST;
        float4 _Color;
        real _AlphaScale;
        
        CBUFFER_END
        
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct Attributes
        {
            float4 vertex : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct Varing
        {
            float2 uv : TEXCOORD0;
            float4 vertex : SV_POSITION;
        };
        
        ENDHLSL

        Pass
        {
            
            Tags{"LightMode"="UniversalForward"}
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            Varing vert (Attributes v)
            {
                Varing o;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float4 frag (Varing i) : SV_Target
            {
                float4 col = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv) * _Color;
                return float4(col.xyz,_Color.a*_AlphaScale);
            }
            ENDHLSL
        }
    }
}
