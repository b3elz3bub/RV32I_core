#define LED ((volatile unsigned int*)0x00001000)

void Order(int n) {
    *LED += n;          
    for(volatile int i = 0; i < 2500000; i++); // 'volatile' prevents GCC deletion
    *LED -= n;
} 

int main() {
    *LED = 0;
    
    while(1) { // Prevents the CPU from running off a cliff
        Order(2);
        Order(4);
        Order(8);
        Order(16);
        Order(32);
        Order(64);
    }
    return 0;
}