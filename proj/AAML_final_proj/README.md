# CFU Playground

## Final Project : Conv Accelerator

### Team members
|||||
|:-:|:-:|:-:|:-:|
|Name|林廉恩|洪子茵|陳永真|
|ID|311553047|310515010|311512074|
|||||

### For TA(s)
***Please make by following cmds***. (Simply extends i$ & d$ size, and change to dynamic branch prediction)
* `make EXTRA_LITEX_ARGS="--cpu-variant=generate+csrPluginConfig:all+cfu+iCacheSize:8192+dCacheSize:8192+prediction:dynamic" prog`
* `make EXTRA_LITEX_ARGS="--cpu-variant=generate+csrPluginConfig:all+cfu+iCacheSize:8192+dCacheSize:8192+prediction:dynamic" load`

The average cycles taken should be around **67M** on golden tests. (Originally 154M)

Accuracy : **0.875**, Latency : **897375.325 us** from last run. (No model modifications)

### Toolchains
1. defaults : run scripts at `${CFU-ROOT}/scripts/setup` (litex / VexRiscv / ... ) 

2. EXTRA_LITEX_ARGS above will install **sbt-1.2.0** and stuffs on first run.

### Features (TBU)

* Software Level
    * algorithm optimizations
    * improving cache hits

* Compiler Level
    * compiler optimizations
    * branch prediction optimization

* Hardware Level
    * upscaled hardware design
    * dynamic branch prediction

### Further Improvements
* Post Processor (commented in cfu.v)
* Increase data bandwidth
