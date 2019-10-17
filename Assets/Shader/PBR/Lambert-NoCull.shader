Shader "PBR/Lambert"{
	Properties{
		_Color("Color Tint", Color) = (1,1,1,1)
		_MainTex ("Main Texture", 2D) = "white"{}
		_Normal ("Normal Textire", 2D) = "bump"{}
        _BumpScale ("Bump Scale", Float) = 1.0
	}
	SubShader{
		Tags {
            "RenderType"="Opaque"
        }

		Pass {
			Tags {
                "LightMode"="ForwardBase" 
            }
			Cull Off
			
			CGPROGRAM

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
            #include "AutoLight.cginc"

			#pragma vertex vert
			#pragma fragment frag
            #pragma multi_compile_fwdbase

			#define PI 3.14159265358979323846264338327950288419716939937510

			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _Normal;
			float4 _Normal_ST;
            float _BumpScale;

			struct a2v{
				float4 vertex: POSITION;
				float3 normal: NORMAL;
				float4 texcoord: TEXCOORD0;
				float4 tangent: TANGENT;
			};
			struct v2f {
				float4 pos:SV_POSITION;
				float2 uv: TEXCOORD0;
				float3 worldPos: TEXCOORD1;
				float3 t2w0: TEXCOORD2;
				float3 t2w1: TEXCOORD3;
				float3 t2w2: TEXCOORD4;
				SHADOW_COORDS(5)

			};

			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				float3 worldNormal = UnityObjectToWorldNormal(v.normal);
				float3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
				float3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;
				o.t2w0 = float3(worldTangent.x, worldBinormal.x, worldNormal.x);
				o.t2w1 = float3(worldTangent.y, worldBinormal.y, worldNormal.y);
				o.t2w2 = float3(worldTangent.z, worldBinormal.z, worldNormal.z);
                TRANSFER_VERTEX_TO_FRAGMENT(o);
				return o;
			}

            inline float3 diffuseLambert(float3 albedo){
                return albedo / PI;
            }

			fixed4 frag(v2f i):SV_TARGET{
				
				float4 albedo = tex2D(_MainTex, i.uv) * _Color;
				float3 ambient = unity_AmbientSky.rgb * albedo.rgb;
				fixed4 packNormal = tex2D(_Normal, i.uv);
                // float shadow = SHADOW_ATTENUATION(i);
                UNITY_LIGHT_ATTENUATION(atten, i, i.worldPos);

				float3 normal = UnpackNormal(packNormal);
                normal.xy *= _BumpScale;
                normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));
                
				normal = normalize(float3(dot(normal, i.t2w0.xyz), dot(normal, i.t2w1.xyz), dot(normal, i.t2w2.xyz)));
				float3 lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
				float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));

				float3 halfDir = normalize(lightDir + viewDir);
				float nv = saturate(dot(normal, viewDir));
				float nl = saturate(dot(normal, lightDir));
				float nh = saturate(dot(normal, halfDir));
				float lv = saturate(dot(lightDir, viewDir));
				float hl = saturate(dot(halfDir, lightDir));

                float3 light = _LightColor0 * atten;

				float3 diffuseTerm = diffuseLambert(albedo.rgb) * light * nl + ambient;
				float3 color = diffuseTerm;
				return fixed4(color, albedo.a);
			}

			ENDCG
		}

        Pass {
			Tags {
                "LightMode"="ForwardAdd" 
            }

            Blend One One
			
			CGPROGRAM

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
            #include "AutoLight.cginc"

			#pragma vertex vert
			#pragma fragment frag
            #pragma multi_compile_fwdadd

			#define PI 3.14159265358979323846264338327950288419716939937510

			fixed4 _Color;
			sampler2D _MainTex;
			float4 _MainTex_ST;
			sampler2D _Normal;
			float4 _Normal_ST;
			float4 _Specular;
			float _Gloss;
			float _Roughness;
			float _F0;

			struct a2v{
				float4 vertex: POSITION;
				float3 normal: NORMAL;
				float4 texcoord: TEXCOORD0;
				float4 tangent: TANGENT;
			};
			struct v2f {
				float4 pos:SV_POSITION;
				float2 uv: TEXCOORD0;
				float3 worldPos: TEXCOORD1;
				float3 t2w0: TEXCOORD2;
				float3 t2w1: TEXCOORD3;
				float3 t2w2: TEXCOORD4;
				float2 v:TEXCOORD5;
			};

			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				float3 worldNormal = UnityObjectToWorldNormal(v.normal);
				float3 worldTangent = UnityObjectToWorldDir(v.tangent);
				float3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;
				o.t2w0 = float3(worldTangent.x, worldBinormal.x, worldNormal.x);
				o.t2w1 = float3(worldTangent.y, worldBinormal.y, worldNormal.y);
				o.t2w2 = float3(worldTangent.z, worldBinormal.z, worldNormal.z);
				o.v = v.vertex;
				return o;
			}

            inline float3 diffuseLambert(float3 albedo){
                return albedo / PI;
            }

			inline float3 disney(float3 baseColor, float roughness, float hl, float nl, float nv){
				float fd90 = 0.5 + 2 * pow(hl, 2) * roughness;
				return  baseColor / PI * (1 + (fd90 - 1) * pow(1 - nl, 5)) * (1 + (fd90 - 1) * pow(1 - nv, 5)); 
			}

			// --------- Specular ---------

			inline float3 schlick(float f0, float hl){
				return f0 + (1 - f0) * pow(1 - hl, 5);
			}

			inline float3 normalDistrGGX(float roughness, float nh){
				float alpha_2 = pow(roughness, 4); // alpha = roughness^2
				return alpha_2 / (PI * pow(pow(nh, 2) * (alpha_2 - 1) + 1, 2));
			}

			inline float3 smithGGX(float roughness, float nv){
				float alpha_2 = pow(roughness, 4); // alpha = roughness^2
				return 2 / (nv + sqrt(alpha_2 + (1 - alpha_2) * pow(nv, 2)));
			}

            inline float3 specularGGX(float3 albedo, float roughness, float nh, float nl, float nv, float hl){
				float3 F = schlick(_F0, hl);
				float3 D = normalDistrGGX(roughness, nh);
				float3 G = smithGGX(roughness, nl) * smithGGX(roughness, nv);
				return max(0,  F * G * D / 4);
            }

			fixed4 frag(v2f i):SV_TARGET{
				
				float roughness = _Roughness;
				float4 albedo = tex2D(_MainTex, i.uv) * _Color;
				fixed4 packNormal = tex2D(_Normal, i.uv);
                float3 light;
                float3 lightDir;

				float3 normal = UnpackNormal(packNormal);
				normal = normalize(float3(dot(normal, i.t2w0.xyz), dot(normal, i.t2w1.xyz), dot(normal, i.t2w2.xyz)));
				float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));

            #ifdef USING_DIRECTIONAL_LIGHT
				lightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                light = _LightColor0.rgb;
            #else
                lightDir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos.xyz);
                float3 lightUV = mul(unity_WorldToLight, float4(i.worldPos, 1)).xyz;
                light = _LightColor0.rgb * tex2D(_LightTexture0, dot(lightUV, lightUV).rr).UNITY_ATTEN_CHANNEL;
            #endif
			
				float3 spacularColor = _Specular.rgb;

				float3 halfDir = normalize(lightDir + viewDir);
				float nv = saturate(dot(normal, viewDir));
				float nl = saturate(dot(normal, lightDir));
				float nh = saturate(dot(normal, halfDir));
				float lv = saturate(dot(lightDir, viewDir));
				float hl = saturate(dot(halfDir, lightDir));


				float3 diffuseTerm = disney(albedo.rgb, roughness, hl, nl, nv) * PI * light.rgb * nl;
				float3 specularTerm = specularGGX(albedo, roughness, nh, nl, nv, hl) * PI * light.rgb * spacularColor * nl;
				float3 fresnel = 1 - _F0;// (1 - schlick(_F0, hl));
				float3 color = diffuseTerm * fresnel + specularTerm;
				return fixed4(color , albedo.a);
			}

			ENDCG
		}


        Pass {
            Name "ShadowCaster"
            Tags { "LightMode"="ShadowCaster" }

            CGPROGRAM
			#include "UnityCG.cginc"

			#pragma vertex vert
			#pragma fragment frag
            #pragma multi_compile_shadowcaster

            struct v2f{
                V2F_SHADOW_CASTER;
            };

            v2f vert(appdata_base v)
            {
                v2f o;
                TRANSFER_SHADOW_CASTER_NORMALOFFSET(o)
                return o;
            }

            float4 frag(v2f i): SV_TARGET
            {
                SHADOW_CASTER_FRAGMENT(i)
            }


            ENDCG
        }
	}
	Fallback "VertexLit"
}