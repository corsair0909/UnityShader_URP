Shader "PostProcessing/GrayTex"
{
    Properties
    {
       [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        _brightness ("Brightness",range(0,1)) = 1
        _Saturate ("Saturate",range(0,1)) = 1
        _contranst ("Contranst",range(-1,2))=1
    }
    SubShader
    {
        Tags { 
            "RenderPipeLine"="UniversalRenderPipeLine"
        }   
        Cull Off
        ZTest Always
        ZWrite Off
        
        HLSLINCLUDE
        
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        CBUFFER_START(UnityProperties)
            real _brightness;
            real _Saturate;
            real _contranst;
        CBUFFER_END
        
        //新的采样函数和采样器，替代 CG中的 Sample2D
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        struct Attributes//新的命名习惯，a2v
        {
            float4 vertex   : POSITION;
            float2 uv       : TEXCOORD0;
        };

        struct Varing//新的命名习惯 v2f
        {
            float2 uv           : TEXCOORD0;
            float4 vertex       : SV_POSITION;
        };
        
        ENDHLSL

        Pass
        {
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            Varing vert (Attributes v)
            {
                Varing o;
                VertexPositionInputs PosInput = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = PosInput.positionCS;
                o.uv = v.uv;
                return o;
            }

            float4 frag (Varing i) : SV_Target
            {
                half4 tex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                float gray = 0.21*tex.r + 0.72*tex.g + 0.072*tex.b;
                tex.rgb *= _brightness;
                tex.rgb = lerp(float3(gray,gray,gray),tex.rgb,_Saturate);
                tex.rgb = lerp(float3(0.5,0.5,0.5),tex.rgb,_contranst);
                return tex;
            }
            ENDHLSL
        }
    }
}
