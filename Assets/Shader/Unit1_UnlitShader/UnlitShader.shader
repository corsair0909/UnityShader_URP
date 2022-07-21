Shader "Unlit/UnlitShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor ("BaseColor",color) = (1,1,1,1)
        _SpecColor ("SpecColor",color) = (1,1,1,1)
        _SpecPower("Gloss",float) = 70
        _Cutoff("Cutoff",float)=0.5
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

        //该文件包含了光照信息和简单的光照计算函数，甚至PBR相关功能的函数
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        
        //适合存放float，half等不占内存的数据类型
        //为了支持SRP Batcher,常量缓冲区，应将除了贴图数据之外的全部属性都包含在内
        //且为了保证后面的Pass都有一样的属性，需要将缓冲区申明在SubShader中
        CBUFFER_START(UnityProperties)
        float4 _MainTex_ST;
        half4 _BaseColor;
        half4 _SpecColor;
        half _SpecPower;
        half _Cutoff;
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
                float4 vertex   : POSITION;
                float2 uv       : TEXCOORD0;
                float3 normal   : NORMAL;
            };

            //新的采样函数和采样器，替代 CG中的 Sample2D
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            
            struct Varing //新的命名习惯 v2f
            {
                float2 uv           : TEXCOORD0;
                float4 vertex       : SV_POSITION;
                float3 ViewWS       : TEXCOORD1;
                float3 NormalWS     : TEXCOORD2;
                float3 WorldPos     : TEXCOORD4;
                //float3 VertexLight  : TEXCOORD3;
            };
            
            Varing vert (Attributes v)
            {
                Varing o;
                //CG中的顶点转换空间：o.vertex = UnityObjectToClipPos(v.vertex);
                //HLSL中的变换方式如下
                VertexPositionInputs PosInput = GetVertexPositionInputs(v.vertex.xyz);
                o.vertex = PosInput.positionCS;
                //o.vertex = TransformObjectToHClip(v.vertex.xyz);

                o.WorldPos = PosInput.positionWS;

                //o.NormalWS = TransformObjectToWorldNormal(v.normal);
                VertexNormalInputs NorInput = GetVertexNormalInputs(v.normal);
                o.NormalWS = NorInput.normalWS;

                o.ViewWS = GetCameraPositionWS() - PosInput.positionWS;
                
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);//uv的获取方式不变

                //o.VertexLight = VertexLighting(PosInput.positionWS,NorInput.normalWS);
                
                return o;
            }

            float4 frag (Varing i) : SV_Target
            {
                half4 col1 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                //half4 col2 = SAMPLE_TEXTURE2D_LOD(_MainTex,sampler_MainTex,i.uv,0);
                half3 NdirWS = normalize(i.NormalWS);
                //Lighting.hlsl中获取主光的方法。
                //Light结构体中包含了灯光的方向、颜色、距离衰减系数、阴影衰减系数
                Light light = GetMainLight();
                float3 LdirWS = normalize(light.direction);
                float3 LightCol = light.color;
                float3 VdirWS = normalize(i.ViewWS);
                
                
                //half3 diffuse = _BaseColor.rgb * col1.rgb * LightingLambert(LightCol,LdirWS,NdirWS);
                float LightAten = saturate(dot(LdirWS,NdirWS)) * 0.5f + 0.5;
                half3 diffuse = _BaseColor.rgb * col1.rgb * LightAten;
                half3 specular  = LightingSpecular(LightCol,LdirWS,NdirWS,VdirWS,_SpecColor,_SpecPower);

                //计算其他光源
                 uint lighCount = GetAdditionalLightsCount();//获取能够影响到这个片段的其他光源的数量
                 for (int it = 0; it < lighCount; ++it)
                 {
                     Light pixelLit = GetAdditionalLight(it,i.WorldPos);//根据索引和片段的位置坐标计算光照，将结果存储在Light结构体中
                     //不要忽略距离衰减因子
                     diffuse += LightingLambert(pixelLit.color,pixelLit.direction,NdirWS) * pixelLit.distanceAttenuation;
                     specular += LightingSpecular(pixelLit.color,LdirWS,NdirWS,VdirWS,_SpecColor,_SpecPower) *
                         pixelLit.distanceAttenuation;
                 }
                
                return float4 (diffuse+specular,1);
            }
            ENDHLSL
        }
        
        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"} //阴影处理Pass

            ZWrite On
            ZTest LEqual
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _GLOSSINESS_FROM_BASE_ALPHA

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment


            //由于这段代码中声明了自己的CBUFFER，与我们需要的不一样，所以我们注释掉他
            //#include "Packages/com.unity.render-pipelines.universal/Shaders/SimpleLitInput.hlsl"
            //它还引入了下面2个hlsl文件
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

    }
}
