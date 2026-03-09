#define LED ((volatile unsigned int*)0x00001000)

int main() {
    while(1) {
        *LED = 4; // Targets LED 2 (Binary 00000100)
        
        // This loop creates the "ON" time
        for(volatile int i = 0; i < 2500000; i++); 
        
        *LED = 0; // Turn everything off
        
        // This loop creates the "OFF" time
        for(volatile int i = 0; i < 2500000; i++); 
    }
}