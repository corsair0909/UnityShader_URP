using System.Collections;
using System.Collections.Generic;
using Unity.Mathematics;
using UnityEngine;

public class Shield : MonoBehaviour
{
    public Material _material;
     public float waveSpeed;

    [Range(0.2f, 20)] public float waveDistance;

    [Range(0.2f, 3)] public float waveIntensity = 1.5f;

    [Range(0.2f, 3)] public float waveRange = 1.5f;

    public GameObject target;
    
    [Range(1, 6)] public static int maxHitPoint = 2;

     public float startDis = 0.02f;

    private Vector4 hitPoints;
    public float hitDis;

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
                hitPoints = hit.point;
                hitDis = startDis;
            }
            
            _material.SetFloat("_MaxHitPoint",maxHitPoint);
            _material.SetFloat("_HitDistance",hitDis);
            _material.SetVector("_HitPoints",hitPoints);
            _material.SetFloat("_WaveIntensity",waveIntensity);
            _material.SetFloat("_WaveRange",waveRange);

            if (hitDis != 0)
            {
                //如果点数据不为0 开始递增距离
                hitDis += 0.1f * waveSpeed;
                Debug.Log("Plus");

            }
            if (hitDis >= waveDistance)
            {
                hitDis -= 0.1f * waveSpeed;;//大于消失距离后归零
                Debug.Log("disslove");
            }


        }
    }
}
