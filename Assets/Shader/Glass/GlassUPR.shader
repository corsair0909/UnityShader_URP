Shader "Unlit/GlassUPR"
{
    Properties
    {
        _Color ("MainCol",color) = (1,1,1,1)
        _NormalTex ("NormalTex",2D) = "White"{}
        _NormalScale ("Scale",float) = 0.2
        _OffsetScale ("AlphaScale",float) = 0.1
        _Alpha ("_Alpha",Range(0,1)) = 0.1
        [KeywordEnum(WS_N,TS_N)]_NormalStage("NormalStage",int) = 0
        
    }
    SubShader
    {
        Tags { 
            // URP 管线的shader需要标明使用的渲染管线标签，让管线识别到
                "RenderPipeLine"="UniversalRenderPipeLine"
                "Queue" = "Transparent"
                "RenderType"="Transparent"
            }   

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        
        CBUFFER_START(UnityProperties)
        float4 _Color;
        float4 _NormalTex_ST;
        real _OffsetScale;
        real _NormalScale;
        real _Alpha;
        
        CBUFFER_END

        float4 _CameraColorTexture_TexelSize;
        
        //新的采样函数和采样器，替代 CG中的 Sample2D
        TEXTURE2D(_NormalTex);
        SAMPLER(sampler_NormalTex);

        TEXTURE2D(_CameraColorTexture); // 抓取屏幕纹理
        SAMPLER(sampler_CameraColorTexture);
        struct Attributes//新的命名习惯，a2v
        {
            float4 vertex   : POSITION;
            float2 uv       : TEXCOORD0;
            float3 normal   : NORMAL;
            float4 tangent  : TANGENT;
        };

        struct Varing//新的命名习惯 v2f
        {
            float2 uv           : TEXCOORD0;
            float4 vertex       : SV_POSITION;
            //float3 ViewWS       : TEXCOORD1;
            float3 NormalWS     : TEXCOORD2;
            //float3 WorldPos     : TEXCOORD4;
            float4 TangentWS    : TEXCOORD5;
            float3 BTangentWS   : TEXCOORD6;
        };
        
        ENDHLSL

        Pass
        {
            
            Tags{"LightMode"="UniversalForward"}
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature_local _NORMAL_STAGE_WS_N
            Varing vert (Attributes v)
            {
                Varing o;
                VertexPositionInputs PosInput = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = PosInput.positionCS;
                VertexNormalInputs NormalInput = GetVertexNormalInputs(v.normal);
                o.NormalWS = NormalInput.normalWS;
                o.uv = TRANSFORM_TEX(v.uv, _NormalTex);//uv的获取方式不变
                o.TangentWS.xyz = NormalInput.tangentWS;
                //unity_WorldTransformParams 是为判断是否使用了奇数相反的缩放
                o.BTangentWS = NormalInput.bitangentWS;
                return o;
            }

            float4 frag (Varing i) : SV_Target
            {
                float4 Ndir = SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,i.uv);
                Ndir.xyz = UnpackNormalScale(Ndir,_NormalScale);
                float2 offset = float2(0,0);
                #ifdef _NORMAL_STAGE_WS_N
                    half3x3 TBN = half3x3(i.TangentWS.xyz,i.BTangentWS.xyz,i.NormalWS.xyz);
                    float3 NdirWS = mul(Ndir.xyz,TBN);
                    offset = NdirWS.xy * _OffsetScale * _CameraColorTexture_TexelSize;
                #else
                    offset = Ndir.xy * _OffsetScale * _CameraColorTexture_TexelSize;
                #endif

                float4 finalColor = SAMPLE_TEXTURE2D(_CameraColorTexture,sampler_CameraColorTexture, i.uv+offset);
                return float4 (finalColor.rgb,_Alpha);
            }
            ENDHLSL
        }
    }
}
