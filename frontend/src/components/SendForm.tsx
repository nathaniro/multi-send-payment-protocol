import { openContractCall } from '@stacks/connect';
import { standardPrincipalCV, uintCV, tupleCV, listCV } from '@stacks/transactions';
import { StacksTestnet } from '@stacks/network';

interface Recipient { address: string; amount?: number; }
function SendForm({ recipients }: { recipients: Recipient[] }) {
  const handleSend = async () => {
    const functionArgs = [
      listCV(recipients.map(r => tupleCV({ to: standardPrincipalCV(r.address), amount: uintCV((r.amount || 0) * 1e6) })))
    ];
    await openContractCall({
      contractAddress: import.meta.env.VITE_CONTRACT_ADDRESS,
      contractName: import.meta.env.VITE_CONTRACT_NAME,
      functionName: 'batch-send',
      functionArgs,
      network: new StacksTestnet(),
      appDetails: { name: 'MSP', icon: '' },
      onFinish: (data) => console.log('TxID:', data.txId)
    });
  };
  return <button onClick={handleSend} className="bg-blue-600 text-white px-4 py-2 rounded">Send Transaction</button>;
}
export default SendForm;
