﻿Shader "MyShader/Postprocess/Fog"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _FogColor ("Fog Color", Color) = (1,1,1,1)
        _ScatterFactor("Scatter Factor", Range(-1, 1)) = 0.3
        _ScatterStrength("Scatter Strength", Range(0, 1)) = 0.1
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
			#include "Lighting.cginc"

            #define PI (3.14159265358979323846264338327950288419716939937510)

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 screenWorldPos: TEXCOORD1;
                float3 ray: TEXCOORD2;
            };

            float4x4 _ViewProjectionInverseMatrix;
            float3 _CameraPos;
            float3 _ViewRange; // (near, far, near - far)
            float3 _CameraClipPlane; // (near, far, near - far)
            float _ScatterFactor;
            float _ScatterStrength;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                float4 p = float4(o.vertex.x, o.vertex.y, -1, 1);
                p = p * _CameraClipPlane.x;
                o.screenWorldPos = mul(_ViewProjectionInverseMatrix, p);
                o.ray = o.screenWorldPos - _CameraPos;
                o.ray = normalize(o.ray) * (length(o.ray) / _CameraClipPlane.x);
                return o;
            }

            sampler2D _ScreenImage;
            sampler2D _MainTex;
            sampler2D _CameraDepthTexture;
            float3 _FogColor;
            float _Density;
            float _Scale;

            #define FOG(FOG_COLOR, ORIGIN_COLOR, F) (FOG_COLOR * F + (1 - F) * ORIGIN_COLOR)

            inline float3 getWorldPos(float depth, float3 ray)
            {
                return (_CameraPos + LinearEyeDepth(depth) * ray.xyz);
            }

            inline float phase(float vl)
            {
                return 1 / (4*PI) * (1 - pow(_ScatterFactor, 2)) / pow(1 + pow(_ScatterFactor, 2) - 2 * _ScatterFactor * vl, 3/2);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float d = _Density;
                float3 color = 1 * tex2D(_ScreenImage, i.uv).rgb;
                float3 depth = tex2D(_CameraDepthTexture, i.uv).rgb;
                float3 worldPos = getWorldPos(depth.r, i.ray);
                float3 ray = worldPos - _CameraPos;
                float3 viewDir = normalize(-ray);
                float3 lightDir = normalize(UnityWorldSpaceLightDir(worldPos));
                float t = (0 - _CameraPos.y) / ray.y;
                if(0 < t && t < 1)
                    worldPos = _CameraPos + ray * t;
                //return worldPos.y - 1;
                fixed4 col = fixed4(color, 1);
                fixed4 fog = fixed4(1,1,1,1);
                fixed4 black = fixed4(0,255,0,1);
                //return step(0, worldPos.x) * step(0, worldPos.z) * fog * col;// fixed4(0,0,0,1) * (1 - t) + fixed4(color, 1) * (t);

                float z = _CameraClipPlane.x + depth * _CameraClipPlane.z;
                z = saturate( (length(worldPos - _CameraPos) - _ViewRange.x) / _ViewRange.z);
                
                float f = (abs(z) - _ViewRange.x) / (_ViewRange.y - _ViewRange.x);
                f = 1 - exp(-pow(d * abs(z), 1));
                // f = saturate((2 - worldPos.y) / (2));
                // f = pow(f, 2);
                //f = 1 - exp(-pow(d * abs(f), 1));
                // depth = (depth + 1) / 2;
                // just invert the colors
                // col.rgb = 1 - col.rgb;
                f *= _Scale;
                color = FOG(_FogColor, color, f);
                float3 scatterLight = _LightColor0.rgb * phase(dot(lightDir, viewDir));
                scatterLight = FOG(scatterLight, float3(0,0,0), f);
                scatterLight = scatterLight * _ScatterStrength;
                return fixed4 (color, 1);
            }
            ENDCG
        }
    }
}
