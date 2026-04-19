#define LED ((volatile unsigned int*)0x00001000)
#define SWITCH ((volatile unsigned int*)0x00002000)

int main() {
    
        while(1)
        {
            *LED = *SWITCH;
        }

    }