import { ethers } from "hardhat";

import { awaitAllDecryptionResults } from "../asyncDecrypt";
import { createInstance } from "../instance";
import { getSigners, initSigners } from "../signers";

describe("WineRegistry", function () {
  before(async function () {
    await initSigners(); // Initialize signers
    this.signers = await getSigners();
  });

  beforeEach(async function () {
    const CounterFactory = await ethers.getContractFactory("WineRegistry");
    this.counterContract = await CounterFactory.connect(this.signers.alice).deploy();
    console.log("account", this.signers.alice.address);
    await this.counterContract.waitForDeployment();
    this.contractAddress = await this.counterContract.getAddress();
    this.instances = await createInstance(); // Set up instances for testing

    // console.log(this.instances.generateKeypair());
  });

  it("should increment by arbitrary encrypted amount", async function () {
    try {
      // Crea la entrada encriptada para la cantidad a incrementar
      const input = this.instances.createEncryptedInput(this.contractAddress, this.signers.alice.address);
      input.add64(200).add64(10).add64(10).add64(10).add64(10).encrypt();
      const encryptedAmount = await input.encrypt();

      // Llamar a la función addWine con la cantidad encriptada
      const tx = await this.counterContract.addWine(
        "costaflores",
        "eskere",
        encryptedAmount.handles[0],
        encryptedAmount.handles[1],
        encryptedAmount.handles[2],
        encryptedAmount.handles[3],
        encryptedAmount.handles[4],
        "arsenico:1-plomo:2",
        encryptedAmount.inputProof,
      );

      // Esperar a que la transacción se confirme
      await tx.wait();

      console.log("WineRegistry contract: ", this.contractAddress);

      const tx2 = await this.counterContract.connect(this.signers.alice).getWine("costaflores");

      const decryptedValueFunction = await this.counterContract
        .connect(this.signers.alice)
        .requestDecryption("costaflores");

      decryptedValueFunction.wait();

      await awaitAllDecryptionResults();

      const decryptedValue = await this.counterContract.getDecryptedIsOrganic();

      const wine = await this.counterContract.getWine("costaflores");

      console.log("Wine:", wine);

      console.log("Decrypted value:", decryptedValue);
    } catch (error) {
      console.error("Error en la transacción:", error);
    }
  });
});
