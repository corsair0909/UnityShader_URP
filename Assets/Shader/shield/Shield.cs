using System.Collections;
using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;

public class Shield : MonoBehaviour
{
    public Material _material;
    [Range(0.2f,5)] public float waveSpeed;

    [Range(0.2f, 20)] public float waveDistance;

    [Range(0.2f, 3)] public float waveIntensity = 1.5f;

    [Range(0.2f, 3)] public float waveRange = 1.5f;

    public GameObject target;
    
    [Range(1, 6)] public static int maxHitPoint = 2;

    [Range(0.01f, 0.1f)] public float startDis = 0.02f;

    private Vector4[] hitPoints = new Vector4[maxHitPoint];
    private float[] hitDis = new float[maxHitPoint];

    private int currentHitPointIndex = 0;
    // Update is called once per frame
    void Update()
    {
        if (Input.GetMouseButtonDown(0))
        {
            Ray ray = Camera.main.ScreenPointToRay(Input.mousePosition);
            RaycastHit hit;
            Physics.Raycast(ray, out hit);
            if (hit.collider.gameObject.name == target.name)
            {
                hitPoints[currentHitPointIndex % maxHitPoint] = hit.point;
                hitDis[currentHitPointIndex % maxHitPoint] = startDis;
            }
            
            _material.SetFloat("_MaxHitPoint",maxHitPoint);
            _material.SetFloatArray("_HitDistance",hitDis);
            _material.SetVectorArray("_HitPoints",hitPoints);
            _material.SetFloat("_WaveIntensity",waveIntensity);
            _material.SetFloat("_WaveRange",waveRange);

            for (int i = 0; i < maxHitPoint; i++)
            {
                if (hitDis[i] != 0)
                {
                    //如果点数据不为0 开始递增距离
                    hitDis[i] += 0.1f * waveSpeed * Time.deltaTime;
                }

                if (hitDis[i] >= waveDistance)
                {
                    hitDis[i] = 0;//大于消失距离后归零
                }
            }
        }
    }
}
