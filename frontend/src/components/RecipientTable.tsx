interface Recipient { address: string; amount?: number; }
function RecipientTable({ recipients }: { recipients: Recipient[] }) {
  return (
    <table className="w-full table-auto border">
      <thead>
        <tr><th>Address</th><th>Amount</th></tr>
      </thead>
      <tbody>
        {recipients.map((r, i) => (
          <tr key={i}><td>{r.address}</td><td>{r.amount}</td></tr>
        ))}
      </tbody>
    </table>
  );
}
export default RecipientTable;
