# KipuBankV2

**Versión:** 2.0 

---

## 📘 Descripción

`KipuBankV2` es una versión mejorada del contrato original **KipuBank**.  
Implementa un **banco descentralizado** que permite **depósitos y retiros** en **ETH y USDC**, con límites configurables en USD y precios actualizados mediante **oráculos Chainlink**.

## 🚀 Características principales

- 💰 **Soporte multi-token:** permite operar con ETH y ERC20.  
- 🧮 **Conversión automática a USD:** mediante oráculos Chainlink.  
- ⚙️ **Límites configurables:**
  - Máximo retiro por transacción (`MAX_WITHDRAFT_PER_TRANSACTION`)
  - Cap total del banco (`MAX_CAP_BANK`)
- 🔐 **Propiedad administrada:** uso de `Ownable` de OpenZeppelin.  
- 🧠 **Control de seguridad:**
  - Validación de balance suficiente.
  - Chequeos de límite antes de cada operación.
  - Uso de errores personalizados (`error`) para eficiencia en gas.



📦 Dependencias

OpenZeppelin Contracts

Ownable.sol

IERC20.sol

Chainlink AggregatorV3Interface
