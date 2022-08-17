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
        _SkyBox ("SkyBox",Cube) = "White"{}
        
        [Space(5)]
        [Header(Parameter)]
        _LightColor ("LightColor",color) = (1,1,1,1)
        _Smoothness("Smoothness",range(0,2)) = 0.1
        _Metalic("Metalic",range(0,1)) = 0
        
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
        float _Metalic;
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

        TEXTURECUBE(_SkyBox);
        SAMPLER(sampler_SkyBox);

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

        //#define PI      3.1416926
        #define INV_PI      0.31830988618379067154

        half  CustomDisneyDiffuse(half NdotV,half NdotL,half LdotH,half Roughness)
        {
            //TODO 修改F90的计算方式
            half F90 = 0.5f + 2*Roughness * LdotH * LdotH;
            half lightScatter = (1+(F90-1)*pow(1-NdotL,5));
            half viewScatter = (1+(F90-1)*pow(1-NdotV,5));
            return INV_PI * lightScatter * viewScatter;
        }

        //Roughness2
        half NDF(half NdotH,half Roughness)
        {
            half NH = max(NdotH,0.0);
            half NdotH2 = NH * NH;
            half Rough = Roughness - 1;
            half denominator = (NdotH2 * Rough) + 1;
            denominator = max(denominator,0.0001);
            return Roughness / pow(denominator,2) * PI;

            // float a2 = pow(lerp(0.002, 1, Roughness), 2);
            // float d = (NdotH * a2 - NdotH) * NdotH + 1.0f; // 2 mad
            // return PI * a2 / (d * d + 1e-7f); 
        }

        half GGX_Smith(half Vec,half k)
        {
            //half OneMinusK = 1-k;
            //half denominator = (Vec * OneMinusK) + k;
            half denominator = lerp(Vec,1,k);
            return Vec / denominator;
        }
        half GGX_SmithGeometry(half NdotL,half NdotV,half Roughness,half Rough2)
        {
            half KInDirectLight = pow(Roughness+1,2)/8;
            //half KIBL = Rough2/2;
            half GGXInLdir = GGX_Smith(NdotL,KInDirectLight);
            half GGXInVdir = GGX_Smith(NdotV,KInDirectLight);
            return GGXInLdir * GGXInVdir;
            
        }
        half3 FresnelShlick(half F0,half LdotH)
        {
            //half Exp = (1-F0) * exp2((-5.55473 * VdotH - 6.98316) * VdotH);
            //return F0+Exp;
            //return F0+(1-F0) * pow(1-VdotH,5);
            float Fre = exp2((-5,55473*LdotH - 6.98316)*LdotH);
            return lerp(Fre,1,F0);
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
            half Roughness = rough*(1.7-0.7 * rough);
            float3 ReDirWS = reflect(-VDir,NDir);
            half MipValue = Roughness * 6;
            float4 SpecColor = SAMPLE_TEXTURECUBE_LOD(unity_SpecCube0,samplerunity_SpecCube0,ReDirWS,MipValue);
            #if !defined(UNITY_USE_NATIVE_HDR)
            return DecodeHDREnvironment(SpecColor,unity_SpecCube0_HDR);
            #else
            return SpecColor.xyz
            #endif
            
            
        }

        float fresnelSchlickRoughness(float cosTheta, float F0, float roughness)
        {
            //TODO 修改了间接光菲涅尔项
            // float oneminus = 1-roughness;
            // return F0 + (max(oneminus,F0)-F0) * pow(1-cosTheta,5);
            float fer = exp2((-5.55473 * cosTheta - 6.98316)*cosTheta);
            return F0+fer * saturate(1-roughness-F0);
        }



        // TODO 使命召唤黑色行动2使用的间接光数值模拟方式
        float2 EnvBRDFApprox(float Roughness, float NoV)
            {
                // [ Lazarov 2013, "Getting More Physical in Call of Duty: Black Ops II" ]
                // Adaptation to fit our G term.
                const float4 c0 = {
                    - 1, -0.0275, -0.572, 0.022
                };
                const float4 c1 = {
                    1, 0.0425, 1.04, -0.04
                };
                float4 r = Roughness * c0 + c1;
                float a004 = min(r.x * r.x, exp2(-9.28 * NoV)) * r.x + r.y;
                float2 AB = float2(-1.04, 1.04) * a004 + r.zw;
                return AB;
            }

        float3 IndirSpecFactor(float roughtness,float smoothness,float3 spe,float3 F0,float NdotV)
        {
            float SurReduction = 1-0.28 * roughtness;
            float Reflectivity = max(max(spe.x,spe.y),spe.z);
            half GrazingTSection = saturate(Reflectivity+smoothness);
            float Fer = Pow4(1-NdotV);
            return lerp(F0,GrazingTSection,Fer)* SurReduction;
            
            
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
                float3x3 TBN = float3x3(i.TangentWS,i.BTangentWS,i.NormalWS);
                float4 Var_Normal = SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,i.uv);
                // float3 Ndir = UnpackNormalScale(Var_Normal,_NormalScale);
                // float3 NdirWS = mul(Ndir,TBN);
                
                float3 NdirWS = UnpackNormal(Var_Normal);//Normal变量还在切线空间下，需要映射之后才能用
                NdirWS.xy *=  _NormalScale;
                NdirWS.z = sqrt(1-saturate(dot(NdirWS.xy,NdirWS.xy)));
                NdirWS = mul(NdirWS,TBN);
                Light MainLight = GetMainLight();

                //float3 NdirWS = normalize(i.NormalWS);
                float3 LDirWS = normalize(MainLight.direction);
                float3 VDirWS = normalize(GetCameraPositionWS());
                
                float Var_Metalic = SAMPLE_TEXTURE2D(_MetalicTex,sampler_MetalicTex,i.uv).r * _Metalic;
                float Var_Ao = SAMPLE_TEXTURE2D(_AOTex,sampler_AOTex,i.uv).r;
                float4 Var_MainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv) * _LightColor;
                float3 HdirWS = normalize(LDirWS+VDirWS);
                float NdotV = max(0.01,dot(NdirWS,VDirWS));
                float NdotL = saturate(dot(NdirWS,LDirWS));
                
                //float LdotV = saturate(dot(LDirWS,VDirWS));
                float NdotH = saturate(dot(NdirWS,HdirWS));
                float VdotH = saturate(dot(VDirWS,HdirWS));
                float LdotH = saturate(dot(LDirWS,HdirWS));

                float perceptualRoughness = SAMPLE_TEXTURE2D(_MetalicTex,sampler_MetalicTex,i.uv).a * _Smoothness;//粗糙度 = 1-光滑度
                perceptualRoughness = max(perceptualRoughness,0.002);
                float roughness = perceptualRoughness * perceptualRoughness;
                float DiffuseResult =  CustomDisneyDiffuse(NdotV,NdotL,LdotH,roughness);//DisneyDiffuse(NdotV,NdotL,LdotV,perceptualRoughness);
                
                float N = NDF(NdotH,roughness);
                float G = GGX_SmithGeometry(NdotL,NdotV,perceptualRoughness,roughness);
                //TODO F0 = 0.04 - albedo 金属度插值
                float F0 = lerp(float3(0.04,0.04,0.04),Var_MainTex.rgb,Var_Metalic).x;
                float3 F = FresnelShlick(F0,LdotH);
                float3 DGF = N*G*F;
                float3 Specular = (DGF * 0.25) / NdotV * NdotL;
                float3 SpecularResult = Specular * PI * MainLight.color;
                
                //TODO 修改Kd漫反射比例计算方式
                float ks = F;
                float kd = 1-ks;
                kd *= (1-Var_Metalic);
                float3 DiffuseColor = kd * DiffuseResult * Var_MainTex.rgb ;

                //直接光照部分 = 直接光漫反射+直接光镜面反射
                float3 InDirectorLight = (DiffuseColor+SpecularResult) * MainLight.color  * NdotL ;

                //间接光漫反射部分
                float3 SHcolor = IBLDiffuseLight(NdirWS) * Var_Ao;
                float3 IndirKS = fresnelSchlickRoughness(NdotV,F0,roughness);
                float3 indirKD = (1-IndirKS) * (1-Var_Metalic);
                float3 indirDiffColor = SHcolor*indirKD * Var_MainTex.rgb;
                float3 indirSpecColor = IBLSpecularLight(VDirWS,NdirWS,roughness);

                //数值计算间接高光因子（LUT）
                float3 indirSpeFactor = IndirSpecFactor(roughness,1-roughness,Specular,F0,NdotV);
                float3 IndirSpec = indirSpecColor * indirSpeFactor;
                float3 IndirCol = indirDiffColor+IndirSpec;
                float3 finalColor = (InDirectorLight + IndirCol);
                
                return float4(finalColor,1);
            }
            ENDHLSL
        }
    }
}
