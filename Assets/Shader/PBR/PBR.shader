Shader "Unlit/PBR"
{
    Properties
    {
        [Header(Texture)]
        _MainTex ("MainTex", 2D) = "white" {}
        _NormalTex ("NormalTex",2D) = "White"{}
        _NormalScale ("Scale",float) = 0.2
        _MetalicTex ("MetalicTex",2D) = "Black"{}
        _AOTex("AOTex",2D) = "white"{}
        _LUT ("LUT",2D) = "White"{}
        
        [Space(5)]
        [Header(Parameter)]
        _LightColor ("LightColor",color) = (1,1,1,1)
        _Smoothness("Smoothness",range(0,0.999)) = 0.1
        
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
        float4 _LightColor;
        float _NormalScale;
        float _Smoothness;
        CBUFFER_END
        
        //新的采样函数和采样器，替代 CG中的 Sample2D
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);

        TEXTURE2D(_NormalTex);
        SAMPLER(sampler_NormalTex);

        TEXTURE2D(_MetalicTex);
        SAMPLER(sampler_MetalicTex);

        TEXTURE2D(_AOTex);
        SAMPLER(sampler_AOTex);

        TEXTURE2D(_LUT);
        SAMPLER(sampler_LUT);

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
            float3 NormalWS     : TEXCOORD1;
            float3 WorldPos     : TEXCOORD2;
            float3 TangentWS    : TEXCOORD3;
            float3 BTangentWS   : TEXCOORD4;
        };

        #define PI      3.1416926
        #define INV_PI      0.31830988618379067154

        half  CustomDisneyDiffuse(half NdotV,half NdotL,half LdotV,half Roughness)
        {
            half F90 = 0.5f + 2*Roughness * LdotV;
            half lightScatter = (1+(F90-1)*pow(1-NdotL,5));
            half viewScatter = (1+(F90-1)*pow(1-NdotV,5));
            return lightScatter * viewScatter;
        }
        half NDF(half NdotH,half Roughness)
        {
            half NdotH2 = NdotH * NdotH;
            half Rough = Roughness - 1;
            half denominator = (NdotH2 * Rough) + 1;
            return INV_PI * Roughness / pow(denominator,2);

            // float a2 = pow(lerp(0.002, 1, Roughness), 2);
            // float d = (NdotH * a2 - NdotH) * NdotH + 1.0f; // 2 mad
            // return PI * a2 / (d * d + 1e-7f); 
        }

        half GGX_Smith(half Vec,half k)
        {
            half OneMinusK = 1-k;
            half denominator = (Vec * OneMinusK) + k;
            return Vec / denominator;
        }
        half GGX_SmithGeometry(half NdotL,half NdotV,half Roughness,half Rough2)
        {
            half KInDirectLight = pow(Roughness+1,2)/8;
            half KIBL = Rough2/2;
            half GGXInLdir = GGX_Smith(NdotL,KInDirectLight);
            half GGXInVdir = GGX_Smith(NdotV,KInDirectLight);

            half GGXIBLLdir = GGX_Smith(NdotL,KIBL);
            half GGXIBLVdir = GGX_Smith(NdotV,KIBL);

            return GGXInLdir * GGXInVdir;
            
        }
        half3 FresnelShlick(half3 F0,half VdotH)
        {
            half Exp = (1-F0) * exp2((-5.55473 * VdotH - 6.98316) * VdotH);
            return F0+Exp;
        }

        float3 IBLDiffuseLight(float Ndir)
        {
            real4 SHCoefficients[7];
            float3 Color = float3(0,0,0);
            SHCoefficients[0] = unity_SHAr;
            SHCoefficients[1] = unity_SHAb;
            SHCoefficients[2] = unity_SHAg;
            SHCoefficients[3] = unity_SHBr;
            SHCoefficients[4] = unity_SHBg;
            SHCoefficients[5] = unity_SHAb;
            SHCoefficients[6] = unity_SHC;
            Color = SampleSH9(SHCoefficients,Ndir);
            return Color;
        }

        float3 IBLSpecularLight(float3 VDir,float3 NDir,half rough)
        {
            half Roughness = rough*(1-rough);
            float3 ReDirWS = reflect(-VDir,NDir);
            half MipValue = Roughness * 6;
            float4 SpecColor = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0,samplerunity_SpecCube0,ReDirWS,MipValue);
            return DecodeHDREnvironment(SpecColor,unity_SpecCube0_HDR);
        }

        float3 fresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
        {
            return F0 + (max(float3(1.0 - roughness, 1.0 - roughness, 1.0 - roughness), F0) - F0) * pow(1.0 - cosTheta, 5.0);
        }
        
        ENDHLSL

        Pass
        {
            
            Tags{"LightMode"="UniversalForward"}
            HLSLPROGRAM
            
            #pragma vertex vert
            #pragma fragment frag
            
            Varing vert (Attributes v)
            {
                Varing o;
                VertexPositionInputs VertexInput = GetVertexPositionInputs(v.vertex.xyz);
                VertexNormalInputs NormalInput = GetVertexNormalInputs(v.normal);
                o.vertex = VertexInput.positionCS;
                o.TangentWS = normalize(mul(unity_ObjectToWorld,v.tangent) * v.tangent.w).xyz;
                o.uv = TRANSFORM_TEX(v.uv,_MainTex);
                o.NormalWS = NormalInput.normalWS;
                o.WorldPos = VertexInput.positionWS;
                o.BTangentWS = normalize(cross(o.NormalWS,o.TangentWS));
                return o;
            }



            float4 frag (Varing i) : SV_Target
            {
                // float3x3 TBN = float3x3(i.TangentWS,i.BTangentWS,i.NormalWS);
                // float4 Var_Normal = SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,i.uv);
                // float3 Ndir = UnpackNormalScale(Var_Normal,_NormalScale);
                // float3 NdirWS = mul(Ndir,TBN);
                Light MainLight = GetMainLight();

                float3 NdirWS = normalize(i.NormalWS);
                float LDirWS = normalize(MainLight.direction);
                float VDirWS = normalize(_WorldSpaceCameraPos.xyz);
                
                float Var_Metalic = SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,i.uv).r;
                float Var_Ao = SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,i.uv).r;
                float4 Var_MainTex = SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,i.uv) * _LightColor;

                float NdotV = saturate(dot(NdirWS,VDirWS));
                float NdotL = saturate(dot(NdirWS,LDirWS));
                float HdirWS = normalize(LDirWS+VDirWS);
                float LdotV = saturate(dot(LDirWS,VDirWS));
                float NdotH = saturate(dot(NdirWS,HdirWS));
                float VdotH = saturate(dot(VDirWS,HdirWS));

                float perceptualRoughness = 1 - _Smoothness;//粗糙度 = 1-光滑度
                float roughness = perceptualRoughness * perceptualRoughness;
                float squareRoughness = roughness * roughness;
                float DiffuseResult = CustomDisneyDiffuse(NdotV,NdotL,LdotV,perceptualRoughness);
                                //DisneyDiffuse(NdotV,NdotL,LdotH,perceptualRoughness);
                //float3 DiffuseResult = Diffuse * Var_MainTex.rgb * MainLight.color/ PI ;
                
                float N = NDF(NdotH,perceptualRoughness);
                float G = GGX_SmithGeometry(NdotL,NdotV,perceptualRoughness,roughness);
                float F0 = lerp(float3(0.4,0.4,0.4),Var_MainTex.rgb,Var_Metalic);
                float3 F = FresnelShlick(F0,VdotH);
                float DGF = N*G*F;
                float Specular = (DGF * 0.25) / NdotV * NdotL;
                float3 SpecularResult = Specular * MainLight.color * NdotL;

                float3 kd = OneMinusReflectivityMetallic(Var_Metalic);
                float3 DiffuseColor = kd * DiffuseResult * MainLight.color * NdotL * Var_MainTex.rgb;

                //直接光照部分 = 直接光漫反射+直接光镜面反射
                float3 InDirectorLight = DiffuseColor+SpecularResult;

                //间接光漫反射部分

                //float2 envBDRF = tex2D(_LUT, float2(lerp(0, 0.99, NdotV), lerp(0, 0.99, roughness))).rg;
                float2 envBRDF = SAMPLE_TEXTURE2D(_LUT,sampler_LUT,float2(lerp(0,0.99,NdotV),lerp(0,0.99,NdotV))).rg;
                float3 ambientSH = IBLDiffuseLight(NdirWS);
                float3 ambient = 0.3 * Var_MainTex.rgb;
                float3 IBLDiffuse = max(float3(0,0,0),ambient+ambientSH);


                float3 IBLSpecular = IBLSpecularLight(VDirWS,NdirWS,perceptualRoughness) * Var_Ao;

                // float surfaceReduction = 1.0 / (roughness*roughness + 1.0); //Liner空间
                // //float surfaceReduction = 1.0 - 0.28*roughness*perceptualRoughness;  //Gamma空间
                // float oneMinusReflectivity = 1 - max(max(SpecularResult.r, SpecularResult.g), SpecularResult.b);
                // float grazingTerm = saturate(_Smoothness + (1 - oneMinusReflectivity));

                float Flast = fresnelSchlickRoughness(NdotV,F0,roughness);
                float KdLast = (1-Flast) * (1-Var_Metalic);

                float3 IBLDiffuseResult = KdLast * IBLDiffuse * Var_MainTex.rgb;
                float3 IBLSpecularResult = IBLSpecular * (KdLast * envBRDF.r+envBRDF.g);
                float3 IBLLight = IBLDiffuseResult + IBLSpecularResult;
                
                float3 finalColor = InDirectorLight + IBLLight;
                
                return float4(finalColor,1);
                return Var_MainTex;
                
            }
            ENDHLSL
        }
    }
}
