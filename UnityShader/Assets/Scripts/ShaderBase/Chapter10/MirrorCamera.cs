using UnityEngine;
using UnityEngine.Rendering.Universal;

// 镜子效果尚未完成，能力有限完成不了了，游戏运行时镜子会变黑，保存场景时镜子会变白，重进场景后又正常
#if UNITY_EDITOR
using UnityEditor;
#endif

[ExecuteAlways]
public class MirrorSystem : MonoBehaviour
{
    [Header("镜子属性")]
    [SerializeField] private GameObject mirrorPlane;
    [SerializeField] private LayerMask reflectionLayers = -1;
    [SerializeField] private Vector2 textureResolution = new Vector2(512, 512);

    [Header("性能优化")]
    [SerializeField][Range(0.1f, 1f)] private float resolutionScale = 0.5f;
    [SerializeField] private bool enableDynamicUpdate = true;
    [SerializeField][Range(1, 4)] private int updateInterval = 1;

    private Camera reflectionCamera;
    private RenderTexture reflectionTexture;
    private Material mirrorMaterial;

    private int frameCount = 0;
    private Vector3 lastMainCamPosition;
    private Quaternion lastMainCamRotation;
    private Vector3 lastMirrorPosition;

    void OnEnable()
    {
        if (reflectionCamera == null)
            CreateReflectionCamera();

        if (reflectionTexture == null)
            SetupRenderTexture();

        ConfigureMirrorMaterial();

        lastMirrorPosition = transform.position;

        Camera cam = GetCurrentCamera();
        if (cam != null)
        {
            lastMainCamPosition = cam.transform.position;
            lastMainCamRotation = cam.transform.rotation;
        }
    }

    void OnDisable()
{
    // 1. 销毁反射相机
    if (reflectionCamera != null)
    {
        // 因为设置了 HideAndDontSave，必须手动销毁
        DestroyImmediate(reflectionCamera.gameObject);
        reflectionCamera = null;
    }

    if (reflectionTexture != null)
        {
            if (Application.isPlaying) Destroy(reflectionTexture);
            else DestroyImmediate(reflectionTexture);
            reflectionTexture = null;
        }
}

    Camera GetCurrentCamera()
    {
        Camera cam = Camera.main;

#if UNITY_EDITOR
        if (!Application.isPlaying)
        {
            if (SceneView.lastActiveSceneView != null)
                cam = SceneView.lastActiveSceneView.camera;
        }
#endif

        return cam;
    }

    void CreateReflectionCamera()
    {
        GameObject camObj = new GameObject("ReflectionCamera");
        camObj.hideFlags = HideFlags.HideAndDontSave;

        camObj.transform.SetParent(transform);
        camObj.transform.localPosition = Vector3.zero;
        camObj.transform.localRotation = Quaternion.identity;

        reflectionCamera = camObj.AddComponent<Camera>();
        reflectionCamera.enabled = false;

        var additionalData = reflectionCamera.GetUniversalAdditionalCameraData();
        additionalData.renderShadows = false;
        additionalData.requiresDepthTexture = true;

        reflectionCamera.cullingMask = reflectionLayers;
        reflectionCamera.clearFlags = CameraClearFlags.Skybox;
    }

    void SetupRenderTexture()
    {
        int width = Mathf.RoundToInt(textureResolution.x * resolutionScale);
        int height = Mathf.RoundToInt(textureResolution.y * resolutionScale);

        reflectionTexture = new RenderTexture(width, height, 24);

        reflectionTexture.wrapMode = TextureWrapMode.Clamp;

#if UNITY_IOS || UNITY_ANDROID
        reflectionTexture.antiAliasing = 1;
        reflectionTexture.filterMode = FilterMode.Bilinear;
#else
        int systemAA = QualitySettings.antiAliasing > 0 ? QualitySettings.antiAliasing : 1;
        reflectionTexture.antiAliasing = Mathf.Min(systemAA, 4);
        reflectionTexture.filterMode = FilterMode.Trilinear;
#endif

        reflectionCamera.targetTexture = reflectionTexture;
    }

    void ConfigureMirrorMaterial()
    {
        if (mirrorPlane == null) return;

        Renderer renderer = mirrorPlane.GetComponent<Renderer>();

        if (renderer != null)
        {
            mirrorMaterial = renderer.sharedMaterial;
            mirrorMaterial.SetTexture("_ReflectionTex", reflectionTexture);
        }
    }

    void LateUpdate()
    {
        Camera mainCamera = GetCurrentCamera();
        if (mainCamera == null) return;

        bool shouldUpdate = ShouldUpdateReflection(mainCamera);

        if (shouldUpdate)
        {
            UpdateReflectionCamera(mainCamera);
            RenderReflection();

            lastMainCamPosition = mainCamera.transform.position;
            lastMainCamRotation = mainCamera.transform.rotation;
            lastMirrorPosition = transform.position;
        }

        frameCount++;

#if UNITY_EDITOR
        if (!Application.isPlaying)
        {
            SceneView.RepaintAll();
        }
#endif
    }

    bool ShouldUpdateReflection(Camera mainCamera)
    {
        if (!enableDynamicUpdate) return false;

        if (frameCount % updateInterval != 0) return false;

        float positionThreshold = 0.1f;
        float rotationThreshold = 1.0f;

        Vector3 positionDelta = mainCamera.transform.position - lastMainCamPosition;
        float rotationDelta = Quaternion.Angle(mainCamera.transform.rotation, lastMainCamRotation);

        bool hasMoved = positionDelta.sqrMagnitude > positionThreshold * positionThreshold;
        bool hasRotated = rotationDelta > rotationThreshold;
        bool mirrorMoved = (transform.position - lastMirrorPosition).sqrMagnitude > 0.001f;

        return hasMoved || hasRotated || mirrorMoved;
    }

    void UpdateReflectionCamera(Camera mainCamera)
    {
        if (mirrorPlane == null) return;

        Transform mirrorTransform = mirrorPlane.transform;

        Vector3 mirrorNormal = mirrorTransform.forward;
        Vector3 mirrorPosition = mirrorTransform.position;

        float d = -Vector3.Dot(mirrorNormal, mirrorPosition);
        Vector4 plane = new Vector4(mirrorNormal.x, mirrorNormal.y, mirrorNormal.z, d);

        Matrix4x4 reflectionMatrix = CalculateReflectionMatrix(plane);

        Vector3 newPos = reflectionMatrix.MultiplyPoint(mainCamera.transform.position);

        reflectionCamera.worldToCameraMatrix =
            mainCamera.worldToCameraMatrix * reflectionMatrix;

        reflectionCamera.transform.position = newPos;
        reflectionCamera.transform.rotation = mainCamera.transform.rotation;

        reflectionCamera.fieldOfView = mainCamera.fieldOfView;
        reflectionCamera.aspect = mainCamera.aspect;

        Vector4 clipPlane = CameraSpacePlane(
            reflectionCamera,
            mirrorPosition,
            mirrorNormal,
            1.0f
        );

        reflectionCamera.projectionMatrix =
            mainCamera.CalculateObliqueMatrix(clipPlane);
    }

    void RenderReflection()
    {
        if (reflectionCamera == null || reflectionTexture == null) return;

        GL.invertCulling = true;

        reflectionCamera.Render();

        GL.invertCulling = false;
    }

    Matrix4x4 CalculateReflectionMatrix(Vector4 plane)
    {
        Matrix4x4 m = Matrix4x4.zero;

        m.m00 = 1F - 2F * plane[0] * plane[0];
        m.m01 = -2F * plane[0] * plane[1];
        m.m02 = -2F * plane[0] * plane[2];
        m.m03 = -2F * plane[0] * plane[3];

        m.m10 = -2F * plane[1] * plane[0];
        m.m11 = 1F - 2F * plane[1] * plane[1];
        m.m12 = -2F * plane[1] * plane[2];
        m.m13 = -2F * plane[1] * plane[3];

        m.m20 = -2F * plane[2] * plane[0];
        m.m21 = -2F * plane[2] * plane[1];
        m.m22 = 1F - 2F * plane[2] * plane[2];
        m.m23 = -2F * plane[2] * plane[3];

        m.m33 = 1F;

        return m;
    }

    Vector4 CameraSpacePlane(Camera cam, Vector3 pos, Vector3 normal, float sideSign)
    {
        float clipPlaneOffset = 0.05f;

        Vector3 offsetPos = pos + normal * clipPlaneOffset;

        Matrix4x4 m = cam.worldToCameraMatrix;

        Vector3 cpos = m.MultiplyPoint(offsetPos);
        Vector3 cnormal = m.MultiplyVector(normal).normalized * sideSign;

        return new Vector4(
            cnormal.x,
            cnormal.y,
            cnormal.z,
            -Vector3.Dot(cpos, cnormal)
        );
    }
}