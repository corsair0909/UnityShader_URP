# UnityShader_URP
Unity_URP渲染管线Shader学习    
记录URP管线下的Shader学习过程    

## [能量盾（更像个泡泡）](https://github.com/corsair0909/UnityShader_URP/tree/main/Assets/Shader/shield)
![QQ20220817-015734-HD](https://user-images.githubusercontent.com/49482455/184947623-f8dc2d2e-1f28-47db-80ee-099a394b83e9.gif)    
### 实现思路    
#### 边缘
NDC坐标的Z值和采样深度图得到的深度值做差值，URP管线下获取深度图需要在管线资产（PipelineAsset）中勾选CameraDepthTexture选项  
#### 顶点动画  
Unity的Sphere顶点数量较小，添加曲面细分着色器后再进行顶点动画。  
顶点偏移方向 = 采样随机贴图（Noise，FlowMap等都可以），沿着法线方向偏移且增加Time因素控制采样UV的偏移。  
#### 中心部分  
URP管线不支持多Pass，不能使用GrabPass获取当前相机渲染的图像，同样需要在PipelineAsset中勾选CameraColorTexture选项，根据之前的Noise对图像采样UV添加偏移（改为透明物体效果更好）
#### 优化  
多Pass渲染背面，URP需要用到RenderFeature来插入一个Pass渲染背面（还没尝试）
对中间图像部分添加通道分离

