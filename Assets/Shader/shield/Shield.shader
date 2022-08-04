Shader "Unlit/URPTemplateShader"
{
    Properties
    {
        [Header(ColorParameter)]
        [HDR]_EmissiveColor ("EmissiveColor",color) = (1,1,1,1)
        [HDR]_EdgeColor ("EdgeColor",Color) = (1,1,1,1)
        [HDR]_FresnalColor ("_FresnalColor",Color) = (1,1,1,1)

        [Space(5)]
        [Header(TexTure)]
        _MainTex ("MainTex",2D) = "White"{}
        _NoiseTex ("NoiseTex",2D) = "gray1"{}
        _NormalTex ("NormalTex",2D) = "White"{}
        _VertexOffsetTex ("VertexOffsetTex",2D) = "gray"{}
        
        [Space(5)]
        [Header(ValParameter)]
        _NoiseSpeed ("扰动速度",range(0,5)) = 0.6
        _EdgeWight ("边缘宽度",range(0,1)) = 0.2
        _FresnelPow ("菲涅尔系数",range(0,10))  = 2
        _NormalScale ("法线缩放",range(0,1)) = 0.2
        _VertexOffsetScale ("顶点偏移缩放",range(0,5)) = 0.2
        
        [Space(5)]
        [Header(TessPatameter)]
        _TessellationFactor("细分系数",int) = 3
        
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
        float4 _MainTex_ST;
        float4 _NormalTex_ST;
        float4 _Noise_ST;
        float4 _VertexOffsetTex_ST; 
        real4 _EmissiveColor;
        real4 _EdgeColor;
        real4 _FresnalColor;
        real _FresnelPow;
        real _NormalScale;
        real _NoiseSpeed;
        real _EdgeWight;
        real _VertexOffsetScale;
        real _TessellationFactor;
        CBUFFER_END

        real _MaxHitPoint;
        real _HitDistance;
        real4 _HitPoints;
        real _WaveIntensity;
        real _WaveRange;
        
        //新的采样函数和采样器，替代 CG中的 Sample2D
        TEXTURE2D(_NormalTex);
        SAMPLER(sampler_NormalTex);
        
        TEXTURE2D(_NoiseTex);
        SAMPLER(sampler_NoiseTex);
        
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        
        TEXTURE2D(_VertexOffsetTex);
        SAMPLER(sampler_VertexOffsetTex);
        
        TEXTURE2D(_CameraColorTexture);
        SAMPLER(sampler_CameraColorTexture);
        
        TEXTURE2D(_CameraDepthTexture);
        SAMPLER(sampler_CameraDepthTexture);

        struct Attributes//新的命名习惯，a2v
        {
            float4 vertex   : POSITION;
            float2 uv       : TEXCOORD0;
            float3 normal   : NORMAL;
            float4 tangent  : TANGENT;
        };

        struct Varing//新的命名习惯 v2f
        {
            float4 uv           : TEXCOORD0;
            float4 vertex       : SV_POSITION;
            float3 ViewWS       : TEXCOORD1;
            float3 NormalWS     : TEXCOORD2;
            float3 WorldPos     : TEXCOORD4;
            float3 TangentWS    : TEXCOORD5;
            float3 BTangentWS   : TEXCOORD6;
            float4 ScrPos       : TEXCOORD7;
            float2 NoiseUV      : TEXCOORD8;
            float   temp         : TEXCOORD9;
        };
        struct PatchTess
        {
            float EdgeTess[3]:SV_TessFactor;
            float InsideTess:SV_InsideTessFactor;
        };
        struct HullOut
        {
            float4 vertex   : POSITION;
            float2 uv       : TEXCOORD0;
            float3 normal   : NORMAL;
            float4 tangent  : TANGENT;
        };
        
        
        ENDHLSL

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            Tags{"LightMode"="UniversalForward"}
            HLSLPROGRAM
            #pragma target 4.6 
            #pragma vertex TessVert
            #pragma hull HS
            #pragma domain DS 
            #pragma fragment frag
            
            Varing vert (Attributes v)
            {
                
                Varing o;
                float2 VertexOffsetUV = v.uv + _VertexOffsetTex_ST.xy + _VertexOffsetTex_ST.zw;
                float Vertexoffset = SAMPLE_TEXTURE2D_LOD(_VertexOffsetTex,sampler_VertexOffsetTex,frac(_Time.x * VertexOffsetUV),0).r;
                v.vertex.xyz += v.normal * _VertexOffsetScale * Vertexoffset;
                o.vertex = TransformObjectToHClip(v.vertex.xyz);
                //CG中的顶点转换空间：o.vertex = UnityObjectToClipPos(v.vertex);
                //HLSL中的变换方式如下
                VertexPositionInputs PosInput = GetVertexPositionInputs(v.vertex.xyz);
                o.WorldPos = PosInput.positionWS;
                o.ScrPos = PosInput.positionNDC;
                VertexNormalInputs NorInput = GetVertexNormalInputs(v.normal);
                o.NormalWS = normalize(NorInput.normalWS);
                o.TangentWS = normalize(NorInput.tangentWS);
                o.BTangentWS = normalize(NorInput.bitangentWS);
                o.uv.xy = TRANSFORM_TEX(v.uv.xy, _MainTex);//uv的获取方式不变
                o.uv.zw = TRANSFORM_TEX(v.uv.xy,_NormalTex);
                o.NoiseUV = v.uv * _Noise_ST.xy + frac(_Noise_ST.zw + _Time.x * _NoiseSpeed);
                //o.temp = temp;
                return o;
            }

            HullOut TessVert(Attributes v)
            {
                HullOut o;
                o.vertex = v.vertex;
                o.uv = v.uv;
                o.normal = v.normal;
                o.tangent = v.tangent;
                return o;
            }
            
            PatchTess hs(InputPatch<HullOut, 3> v)
            {
                PatchTess o;
                o.EdgeTess[0] = _TessellationFactor;
                o.EdgeTess[1] = _TessellationFactor;
                o.EdgeTess[2] = _TessellationFactor;
                o.InsideTess = _TessellationFactor;
                return o;
            }
            [domain("tri")]
            [partitioning("fractional_odd")]
            [outputtopology("triangle_cw")]
            [patchconstantfunc("hs")]
            [outputcontrolpoints(3)]
            HullOut HS(InputPatch<HullOut, 3> v, uint id :SV_OutputControlPointID)
            {
                return v[id];
            }

            [domain("tri")]
            Varing DS(PatchTess tessFactor, const OutputPatch<HullOut, 3> vi, float3 bary :SV_DomainLocation)
            {
                Attributes v;
                v.vertex = vi[0].vertex * bary.x + vi[1].vertex * bary.y + vi[2].vertex * bary.z;
                v.normal = vi[0].normal * bary.x + vi[1].normal * bary.y + vi[2].normal * bary.z;
                v.uv = vi[0].uv * bary.x + vi[1].uv * bary.y + vi[2].uv * bary.z;
                Varing o = vert(v);
                return o;
            }
            
            float4 frag (Varing i) : SV_Target
            {
                // float3x3 TBN = float3x3(i.TangentWS,i.BTangentWS,i.NormalWS);
                // float4 Ndir = SAMPLE_TEXTURE2D(_NormalTex,sampler_NormalTex,i.uv.zw);
                // float3 NdirWS = mul(UnpackNormalScale(Ndir,_NormalScale),TBN);
                float3 NdirWS  = i.NormalWS;
                float3 VdirWS = normalize(GetCameraPositionWS() - i.WorldPos);
                float Fresnal =pow(1-saturate(dot(VdirWS,NdirWS)),_FresnelPow);


                float3 scrPos = i.ScrPos.xyz/i.ScrPos.w;

                
                float var_DepthTex = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_CameraDepthTexture,scrPos.xy);
                float halfWight = _EdgeWight / 2;
                float depth = LinearEyeDepth(var_DepthTex,_ZBufferParams);
                float srcDepth = LinearEyeDepth(scrPos.z,_ZBufferParams);
                float diff = saturate(abs(srcDepth - depth)/halfWight);
                

                float offset = SAMPLE_TEXTURE2D(_NoiseTex,sampler_NoiseTex,i.uv).r;
                float4 bumpColor1 = SAMPLE_TEXTURE2D(_NoiseTex,sampler_NoiseTex,i.NoiseUV+offset + frac(float2(_NoiseSpeed * _Time.x,0)));
                float4 bumpColor2 = SAMPLE_TEXTURE2D(_NoiseTex,sampler_NoiseTex,i.NoiseUV+offset - frac(float2(0,_NoiseSpeed * _Time.x)));
                float3 normal = UnpackNormal((bumpColor1+bumpColor2)/2);

                //float subTemp = 1 - i.temp;
                
                float RampscrPosX = scrPos.x + normal.x * _NormalScale;
                float RampscrPosY = scrPos.y + normal.y * _NormalScale;
                
                float4 var_ScrTex = SAMPLE_TEXTURE2D(_CameraColorTexture,sampler_CameraColorTexture,float2(RampscrPosX,RampscrPosY));
                float4 var_mainTex = SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,float2(RampscrPosX,RampscrPosY)) * _EmissiveColor;
                float3 scrColor = var_mainTex.rgb * var_ScrTex + Fresnal*_EdgeColor;
                float3 finalColor = lerp(_EdgeColor,scrColor,diff);
                return float4 (finalColor,var_mainTex.a);
            }
            ENDHLSL
        }
    }
}
