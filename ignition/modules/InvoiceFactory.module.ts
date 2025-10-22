import { buildModule } from "@nomicfoundation/hardhat-ignition/modules";

/**
 * Ignition module for deploying InvoiceFactory
 *
 * The InvoiceFactory deploys its own Invoice implementation contract
 * in the constructor using EIP-1167 minimal proxy pattern.
 *
 * Usage:
 *   npx hardhat ignition deploy ignition/modules/InvoiceFactory.module.ts --network <network-name>
 *
 * Example (local):
 *   npx hardhat ignition deploy ignition/modules/InvoiceFactory.module.ts --network localhost
 *
 * Example (testnet):
 *   npx hardhat ignition deploy ignition/modules/InvoiceFactory.module.ts --network sepolia
 *
 * After deployment:
 *   - InvoiceFactory address will be available at the returned address
 *   - Invoice implementation address can be retrieved by calling invoiceFactory.invoiceImplementation()
 *   - Use invoiceFactory.deployInvoice(paramsHash) to create new invoice clones
 */
export default buildModule("InvoiceFactory", (m) => {
  // Deploy InvoiceFactory (which deploys Invoice implementation internally)
  const invoiceFactory = m.contract("InvoiceFactory", [], {
    id: `InvoiceFactory_${process.env.VERSION_TAG ?? 0}`,
  });

  return {
    invoiceFactory,
  };
});
