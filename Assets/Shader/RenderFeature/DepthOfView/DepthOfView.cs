using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class DepthOfView : ScriptableRendererFeature
{
    [System.Serializable] //可序列化
    public class  MySetting
    {
        public Material _material;
        public string PassName = "Depth Of View";
        public RenderPassEvent Event = RenderPassEvent.AfterRenderingOpaques;
        [Tooltip("下采样次数"),Range(1, 4)] public int DowmSample = 1;//下采样次数，越大性能越好，效果越差
        [Range(10,100)] public int LoopCount = 50;
        [Range(0, 0.5f)] public float BlurSmooth=0.2f;
        [Range(0.2f, 1)] public float Radius = 0.5f;
        public float NearDistance = 5;
        public float FarDistance = 9;
    }

    public MySetting setting = new MySetting();


    class DepthOfViewPass : ScriptableRenderPass
    {
        private int width;
        private int height;
        private RenderTargetIdentifier sour;
        readonly private int BlurID = Shader.PropertyToID("blur");
        readonly private int SourceID = Shader.PropertyToID("_BlurTex");

        public Material Mat;
        public string Name;
        public RenderPassEvent renderEvent;
        public int DowmSample;
        public int LoopCount;
        public float BlueSmooth;
        public float Radius;
        public float NearDistance;
        public float FarDistance;
        public void SetUp(RenderTargetIdentifier sour)
        {
            this.sour = sour;
            Mat.SetFloat("_StartDis",NearDistance);
            Mat.SetFloat("_EndDis",FarDistance);
            Mat.SetFloat("_Loop",LoopCount);
            Mat.SetFloat("_BlurSmooth",BlueSmooth);
            Mat.SetFloat("_Radius",Radius);
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(Name);
            RenderTextureDescriptor desc = renderingData.cameraData.cameraTargetDescriptor;
            height = desc.height / DowmSample;
            width = desc.width / DowmSample;
            cmd.GetTemporaryRT(BlurID,width,height,0,FilterMode.Bilinear,RenderTextureFormat.ARGB32);
            cmd.GetTemporaryRT(SourceID,desc);
            cmd.CopyTexture(sour,SourceID);
            cmd.Blit(sour,BlurID,Mat,0);
            cmd.Blit(BlurID,sour,Mat,1);
            context.ExecuteCommandBuffer(cmd);
            cmd.ReleaseTemporaryRT(BlurID);
            cmd.ReleaseTemporaryRT(SourceID);
            CommandBufferPool.Release(cmd);
        }
    }
    //构造方法需要在Creat方法中调用
    private DepthOfViewPass DOV;
    
    public override void Create()
    {
        DOV = new DepthOfViewPass();
        DOV.renderEvent = setting.Event;
        DOV.Mat = setting._material;
        DOV.Name = setting.PassName;
        DOV.Radius = setting.Radius;
        DOV.BlueSmooth = setting.BlurSmooth;
        DOV.DowmSample = setting.DowmSample;
        DOV.FarDistance = setting.FarDistance;
        DOV.NearDistance = setting.NearDistance;
        DOV.LoopCount = setting.LoopCount;
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        DOV.SetUp(renderer.cameraColorTarget);
        renderer.EnqueuePass(DOV);
    }
}
