Shader "Unlit/UnlitShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor ("BaseColor",color) = (1,1,1,1)
    }
    SubShader
    {
        //URP不再支持多个渲染Pass
        //渲染Pass ：LightMode = UniversalForward，只能有一个，负责渲染，输出到帧缓存中
        //投影Pass ：LightMode = ShadowCaster，用于计算投影
        //深度Pass ：LightMode = DepthOnly 如果管线设置了生成深度图，会通过这个Pass渲染出来
        //其他Pass ：用于烘焙
        
        
        Tags { 
                // URP 管线的shader需要标明使用的渲染管线标签，让管线识别到
                "RenderPipeLine"="UniversalRenderPipeLine" 
                "Queue" = "Geometry"
                "RenderType"="Opaque"
             }
        
        
        // 引入由CGINCLUDE变为 HLSLINCLUDE
        HLSLINCLUDE

        
        //CGUnity.cginc包含文件 改为如下文件
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        
        //适合存放float，half等不占内存的数据类型
        //为了支持SRP Batcher,常量缓冲区，应将除了贴图数据之外的全部属性都包含在内
        //且为了保证后面的Pass都有一样的属性，需要将缓冲区申明在SubShader中
        CBUFFER_START(UnityProperties)
        float4 _MainTex_ST;
        half4 _BaseColor;
        CBUFFER_END
        
        ENDHLSL

        Pass
        {
            Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes//新的命名习惯，a2v
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            //新的采样函数和采样器，替代 CG中的 Sample2D
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            struct Varing //新的命名习惯 v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };
            
            Varing vert (Attributes v)
            {
                Varing o;
                //CG中的顶点转换空间：o.vertex = UnityObjectToClipPos(v.vertex);
                //HLSL中的变换方式如下
                VertexPositionInputs PosInput = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = PosInput.positionCS;
                //o.vertex = TransformObjectToHClip(v.vertex.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);//uv的获取方式不变
                return o;
            }

            float4 frag (Varing i) : SV_Target
            {
                half4 col1 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                //half4 col2 = SAMPLE_TEXTURE2D_LOD(_MainTex,sampler_MainTex,i.uv,0);
                return col1 * _BaseColor;
            }
            ENDHLSL
        }
    }
}
