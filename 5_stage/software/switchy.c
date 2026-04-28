#define LED ((volatile unsigned int*)0x80000000)
#define SWITCH ((volatile unsigned int*)0x80000004)

int main() {
    
        while(1)
        {
            *LED = *SWITCH;
        }

    }