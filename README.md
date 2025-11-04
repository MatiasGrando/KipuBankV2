# KipuBankV2

**Versión:** 2.0 

---

## 📘 Descripción

`KipuBankV2` es una versión mejorada del contrato original **KipuBank**.  
Implementa un **banco descentralizado** que permite **depósitos y retiros** en **ETH y USDC**, con límites configurables en USD y precios actualizados mediante **oráculos Chainlink**.

El contrato optimiza el consumo de gas, mejora la seguridad, modularidad y claridad del código, y agrega documentación completa con formato **NatSpec**.

## 🚀 Principales mejoras

- **Soporte multi-token:** ETH y ERC20 (como USDC).  
- **Oráculos Chainlink:** para conversión automática de valores a USD.  
- **Control de propiedad:** sistema de `Ownable` con propietario inicial.  
