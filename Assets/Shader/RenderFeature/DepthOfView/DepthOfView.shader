Shader "Unlit/URPTemplateShader"
{
    Properties
    {
        [HideInInspector]_MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        
        Tags { 
            "RenderPipeLine"="UniversalRenderPipeLine"
        }   

        HLSLINCLUDE
        
        //CGUnity.cginc包含文件 改为如下文件
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        CBUFFER_START(UnityProperties)
        float4 _MainTex_ST;
        float _StartDis;
        float _EndDis;
        float _Loop;//迭代次数
        float _BlurSmooth;//模糊因子
        float _Radius;//旋转半径
        CBUFFER_END

        float4 _MainTex_TexelSize;
        //新的采样函数和采样器，替代 CG中的 Sample2D
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_BlurTex);
        SAMPLER(sampler_BlurTex);

        TEXTURE2D(_CameraDepthTexture);//深度图用来确定模糊范围
        SAMPLER(sampler_CameraDepthTexture);

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

        Pass // 旋转采样点PASS
        {
            Cull Off
            ZTest Always
            ZWrite Off
            
            Tags{"LightMode"="UniversalForward"}
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            Varing vert (Attributes v)
            {
                Varing o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (Varing i) : SV_Target
            {
                float Angle = 2.3398;
                float2x2 RotateMatrix = float2x2(cos(Angle),-sin(Angle),sin(Angle),cos(Angle));
                float2 UvOffset = float2(_Radius,0);
                float r;//每次旋转的半径
                float2 uv;
                float4 result;
                for (int it = 1; it < _Loop; it++)
                {
                    r = sqrt(it); //
                    UvOffset = mul(RotateMatrix,UvOffset);
                    uv = i.uv + _MainTex_TexelSize.xy * UvOffset * r;
                    result += SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,uv);
                }
                return result / _Loop-1;
            }
            ENDHLSL
        }
         Pass // 计算范围PASS
        {
            Cull Off
            ZTest Always
            ZWrite Off
            
            Tags{"LightMode"="UniversalForward"}
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            Varing vert (Attributes v)
            {
                Varing o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (Varing i) : SV_Target
            {
                float depth = Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,i.uv).x,_ZBufferParams);
                float4 var_MainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                float4 var_BlurTex = SAMPLE_TEXTURE2D(_BlurTex,sampler_BlurTex,i.uv);
                _StartDis *= _ProjectionParams.w;
                _EndDis *= _ProjectionParams.w;
                // 近处模糊 depth越小越要模糊，_StartDis+_BlurSmooth处结束模糊，所以取反
                float dis = 1-smoothstep(_StartDis,saturate(_StartDis+_BlurSmooth),depth);
                // 远处模糊 Depth越大越靠近模糊，累加结果得到景深结果
                dis += smoothstep(_EndDis,saturate(_EndDis+_BlurSmooth),depth);
                
                float4 combine =lerp(var_MainTex,var_BlurTex,dis);//根据结果差值模糊和原图
                return combine;
            }
            ENDHLSL
        }
    }
}
