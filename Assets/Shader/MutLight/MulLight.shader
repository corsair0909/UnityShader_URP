Shader "Unlit/URPTemplateShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("MainCol",color) = (1,1,1,1)
        _NormalTex ("NormalTex",2D) = "White"{}
        _NormalScale ("Scale",float) = 0.2
        _AlphaScale ("AlphaScale",Range(0,1)) = 0.1
        _SpecColor ("SpecColor",color) = (1,1,1,1)
        _SpecPower("Gloss",float) = 70
        
        [Space(5)]
        [Header(AddLighting)]
        [KeywordEnum(ON,OFF)] _ADD_LIGHT ("MultLight",float) = 1
        
        
//        [Space(15)]
//        [Header(Blend Mode)]
//        [Enum(UnityEngine.Rendering.BlendOp)] _BlendOp("BlendOp",float) = 1
//        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend("SrcBlend",float) = 1
//        [Enum(UnityEngine.Rendering.BlendMode)] _DesBlend("DesBlend",float) = 1
        
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
        float4 _Color;
        half4 _SpecColor;
        real _AlphaScale;
        real _SpecPower;
        real _NormalScale;
        
        CBUFFER_END
        
        //新的采样函数和采样器，替代 CG中的 Sample2D
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_NormalTex);
        SAMPLER(sampler_NormalTex);

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
            float3 ViewWS       : TEXCOORD1;
            float3 NormalWS     : TEXCOORD2;
            float3 WorldPos     : TEXCOORD4;
            float4 TangentWS    : TEXCOORD5;
            float3 BTangentWS   : TEXCOORD6;
        };
        
        
        ENDHLSL

        Pass
        {
            
            Tags{"LightMode"="UniversalForward"}
            //Blend [_SrcBlend] [_DesBlend]
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag

            //TODO 解决阴影问题
			// #pragma multi_compile  _MAIN_LIGHT_SHADOWS
			// #pragma multi_compile  _MAIN_LIGHT_SHADOWS_CASCADE
			// #pragma multi_compile  _SHADOWS_SOFT

            
            #pragma shader_feature _ADD_LIGHT_ON _ADD_LIGHT_OFF //shader feature
            
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
                o.NormalWS = normalize(NorInput.normalWS);

                o.ViewWS = GetCameraPositionWS() - PosInput.positionWS;
                
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);//uv的获取方式不变

                o.TangentWS.xyz = normalize(TransformObjectToWorld(v.tangent));

                //unity_WorldTransformParams 是为判断是否使用了奇数相反的缩放
                o.BTangentWS = normalize(cross(o.NormalWS,o.TangentWS.xyz) * v.tangent.w * unity_WorldTransformParams.w);

                //o.VertexLight = VertexLighting(PosInput.positionWS,NorInput.normalWS);

                return o;
            }

            float4 frag (Varing i) : SV_Target
            {
                //half3x3 TBN = half3x3(i.TangentWS.xyz,i.BTangentWS.xyz,i.NormalWS.xyz);
                
                half4 col1 = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv);
                //half4 col2 = SAMPLE_TEXTURE2D_LOD(_MainTex,sampler_MainTex,i.uv,0);
                
                half3 NdirWS = normalize(i.NormalWS);
                //TBN矩阵转换切线空间法线
                 // half4 var_Normal = SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,i.uv);
                 // half3 NdirTS = UnpackNormalScale(var_Normal,_NormalScale);
                
                //NdirTS.z = pow((1-pow(NdirTS.x,2)-1-pow(NdirTS.y,2)),0.5);
                 // NdirTS.z = sqrt(1-saturate(dot(NdirTS.xy,NdirTS.xy))); //规范化法线
                 // half3 NdirWS = mul(NdirTS,TBN); // 右乘TBN = 左乘TBN的逆矩阵
                

                //产生阴影的方法
                //需要定义 上面两个宏才可以生效
                float4 ShadowCoord = TransformWorldToShadowCoord(i.WorldPos);
                //Light shadowLight = GetMainLight(ShadowCoord);//阴影空间下的灯光
                
                
                //Lighting.hlsl中获取主光的方法。
                //Light结构体中包含了灯光的方向、颜色、距离衰减系数、阴影衰减系数
                Light light = GetMainLight(ShadowCoord);
                half shadow = light.shadowAttenuation;
                
                float3 LdirWS = normalize(light.direction);
                float3 LightCol = light.color;
                float3 VdirWS = normalize(i.ViewWS);
                
                
                //half3 diffuse = _BaseColor.rgb * col1.rgb * LightingLambert(LightCol,LdirWS,NdirWS);
                float NdotL = saturate(dot(LdirWS,NdirWS)) * 0.5f + 0.5;

                //real HLSL中的数据类型，根据不同平台被编译成float或fixed
                real3 diffuse = _Color.rgb * col1.rgb * NdotL * LightCol * shadow;
                real3 specular  = LightingSpecular(LightCol,LdirWS,NdirWS,VdirWS,_SpecColor,_SpecPower);

                //计算其他光源
                #if _ADD_LIGHT_ON
                 float3 MutLight =float3(0,0,0); 
                 uint lighCount = GetAdditionalLightsCount();//获取能够影响到这个片段的其他光源的数量
                 for (int it = 0; it < lighCount; ++it)
                 {
                     Light pixelLit = GetAdditionalLight(it,i.WorldPos);//根据索引和片段的位置坐标计算光照，将结果存储在Light结构体中
                     float3 LDirWS = normalize(pixelLit.direction);
                     //不要忽略距离衰减因子
                     MutLight += LightingLambert(pixelLit.color,LDirWS,NdirWS) * pixelLit.distanceAttenuation;
                 }
                #else
                 float3 MutLight = float3(0,0,0);
                #endif


                float3 finalColor = diffuse+specular+MutLight.rgb;
                return float4 (finalColor,1);
            }
            ENDHLSL
        }
        //投射阴影
        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}
