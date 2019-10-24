﻿using UnityEngine;
using UnityEngine.Rendering;

[ExecuteInEditMode]
public class PerlinNoise: MonoBehaviour, ICustomEditorEX
{
    public RenderTexture TargetTexture;
    public ComputeShader Shader;
    // Pixels per grid
    [Delayed]
    public int GridSize = 64;
    [Delayed]
    public int MinIterateSize = 4;
    public bool UpdateEveryFrame = false;
    RenderTexture GridBuffer;
    bool inited = false;
    int size;
    int gridBufferSize;
    int gridRenderKernel;
    int noiseRenderKernel;
    void Start()
    {
        if (!TargetTexture || !Shader)
            return;
        Init();
        UpdateNoise();
    }
    
    [EditorButton("Reload")]
    void Init()
    {
        inited = true;
        size = TargetTexture.width;
        gridBufferSize = size / MinIterateSize;

        if(!GridBuffer)
        {
            GridBuffer = new RenderTexture(gridBufferSize, gridBufferSize, 0, RenderTextureFormat.RGFloat);
            GridBuffer.filterMode = FilterMode.Point;
            GridBuffer.wrapMode = TextureWrapMode.Repeat;
            GridBuffer.enableRandomWrite = true;
            GridBuffer.Create();
        }
        if(!TargetTexture.enableRandomWrite)
        {
            TargetTexture.Release();
            TargetTexture.enableRandomWrite = true;
            TargetTexture.Create();
        }
        if (!TargetTexture.IsCreated())
            TargetTexture.Create();

        Shader.SetFloat("Seed", UnityEngine.Random.value);
        Shader.SetInt("GridSize", GridSize);
        Shader.SetInt("MinIterateSize", MinIterateSize);
        Shader.SetVector("Size", new Vector2(TargetTexture.width, TargetTexture.height));
        //Shader.SetVector("GridSize", new Vector2(gridBufferSize, gridBufferSize));

        gridRenderKernel = Shader.FindKernel("RandGrid");
        noiseRenderKernel = Shader.FindKernel("RenderNoise");

        Shader.SetTexture(gridRenderKernel, "Grid", GridBuffer);
        Shader.SetTexture(noiseRenderKernel, "Grid", GridBuffer);
        Shader.SetTexture(noiseRenderKernel, "NoiseTextureOutput", TargetTexture);
    }
    private void Update()
    {
        if (UpdateEveryFrame)
            UpdateNoise();

    }

    public void UpdateNoise()
    {
        if (!TargetTexture || !Shader)
            return;
        //  Init();

        Shader.SetFloat("Seed", UnityEngine.Random.value);
        Shader.Dispatch(gridRenderKernel, gridBufferSize / 8, gridBufferSize / 8, 1);
        Shader.Dispatch(noiseRenderKernel, size / 32, size / 32, 1);
    }

    private void OnGUI()
    {
        if (!inited)
            return;
        //GUI.DrawTexture(new Rect(0, 0, 1024, 1024), TargetTexture, ScaleMode.ScaleToFit, false);
        //GUI.DrawTexture(new Rect(1024, 0, 1024, 1024), GridBuffer, ScaleMode.ScaleToFit, false);
    }
}