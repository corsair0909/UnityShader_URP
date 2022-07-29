using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.UI;
namespace EasyGameStudio.Disslove_urp
{
    public class Demo_control : MonoBehaviour
    {
        public GameObject[] game_objects;
        public AudioSource audio_source;
        public AudioClip ka;
        public Text text_title;
        public string[] string_titles;

        private int index = 0;

        void Start()
        {
           
        }

        public void on_next_btn()
        {
            this.index++;
            if (this.index >= this.game_objects.Length)
                this.index = 0;


            for (int i = 0; i < this.game_objects.Length; i++)
            {
                if (i == this.index)
                {
                    this.game_objects[i].SetActive(true);
                }
                else
                {
                    this.game_objects[i].SetActive(false);
                }
            }

            this.text_title.text = this.string_titles[this.index];

            this.audio_source.PlayOneShot(this.ka);
        }

        public void on_previous_btn()
        {
            this.index--;
            if (this.index < 0)
                this.index = this.game_objects.Length-1;


            for (int i = 0; i < this.game_objects.Length; i++)
            {
                if (i == this.index)
                {
                    this.game_objects[i].SetActive(true);
                }
                else
                {
                    this.game_objects[i].SetActive(false);
                }
            }

            this.text_title.text = this.string_titles[this.index];

            this.audio_source.PlayOneShot(this.ka);
        }
    }
}