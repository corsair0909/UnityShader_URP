using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;


//自定义的RenderFeature 要继承ScriptableRendererFeature类
public class PostProcessRenderFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class mySetting
    {
        public RenderPassEvent passEvent = RenderPassEvent.AfterRenderingTransparents;//渲染时机
        public Material mat;//使用材质
        public int matPassIndex = -1;//材质中的哪一个pass
    }

    public mySetting _setting = new mySetting();
    
    public class CustomRenderPass : ScriptableRenderPass
    {
        public Material passMat = null;
        public int passIndex = 0;
        public FilterMode passFilterMode { get; set; }
        private RenderTargetIdentifier passSource { get; set;} // 源图像
        private RenderTargetHandle TempleColorTex; // 临时RT
        private string passTag;

        public CustomRenderPass(RenderPassEvent passEvent,Material passMat,int passIndex,string passTag)
        {
            this.renderPassEvent = passEvent;
            this.passIndex = passIndex;
            this.passMat = passMat;
            this.passTag = passTag;
        }

        public void SetupSourceTex(RenderTargetIdentifier RT)
        {
            this.passSource = RT;
        }
        
        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            CommandBuffer cmd = CommandBufferPool.Get(passTag);
            RenderTextureDescriptor opaqueDes = renderingData.cameraData.cameraTargetDescriptor;
            //深度缓冲的精度 0、16、24/32为精度
            opaqueDes.depthBufferBits = 0;
            cmd.GetTemporaryRT(TempleColorTex.id,opaqueDes,passFilterMode); //申请临时图像
            Blit(cmd,passSource,TempleColorTex.Identifier(),passMat,passIndex);//source图像被pass处理完的结果存储到临时图像
            Blit(cmd,TempleColorTex.Identifier(),passSource);//从临时图像存储回source
            context.ExecuteCommandBuffer(cmd);//执行命令
            //释放命令
            CommandBufferPool.Release(cmd);
            cmd.ReleaseTemporaryRT(TempleColorTex.id);
        }
    }

    private CustomRenderPass postProcessPass;
    
    public override void Create()//用于初始化
    {
        int passInt = _setting.mat == null ? 1 : _setting.mat.passCount; // 计算材质中的pass数量
        _setting.matPassIndex = Mathf.Clamp(_setting.matPassIndex, -1, passInt);
        postProcessPass = new CustomRenderPass(_setting.passEvent, _setting.mat, _setting.matPassIndex,name);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        //将值传入pass
        var src = renderer.cameraColorTarget;
        postProcessPass.SetupSourceTex(src);
        renderer.EnqueuePass(postProcessPass);
    }
}
