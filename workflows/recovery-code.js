// This source is embedded into the exported n8n Code node by build-workflow.mjs.
function createRecoveryPlan(input, executionId, executedAt) {
  const profile = input.profile;
  const forecast = input.forecast;
  const hardship = input.hardship;
  const money = (pence) => new Intl.NumberFormat('en-GB', {
    style: 'currency', currency: 'GBP',
  }).format(pence / 100);
  if (!profile || !forecast || !['income_drop', 'unexpected_bill', 'complaint'].includes(hardship)) {
    throw new Error('A profile, forecast and recognised hardship are required.');
  }
  for (const key of ['openingBalancePence', 'monthlyIncomePence', 'monthlyEssentialsPence', 'debtBalancePence']) {
    if (!Number.isSafeInteger(profile[key]) || Math.abs(profile[key]) > 100000000 || (key !== 'openingBalancePence' && profile[key] < 0)) {
      throw new Error(`profile.${key} must be integer pence within the demo range.`);
    }
  }
  if (!Number.isSafeInteger(forecast.shortfallPence) || forecast.shortfallPence < 0 || forecast.shortfallPence > 100000000) {
    throw new Error('forecast.shortfallPence must be non-negative integer pence.');
  }
  const name = typeof profile.name === 'string' ? profile.name.trim().slice(0, 100) : '';
  if (!name) throw new Error('A customer name is required.');
  const date = typeof forecast.shortfallDate === 'string' && /^\d{4}-\d{2}-\d{2}/.test(forecast.shortfallDate)
    ? forecast.shortfallDate.slice(0, 10) : null;
  if (forecast.shortfallPence > 0 && (!date || Number.isNaN(Date.parse(date)) || new Date(date).toISOString().slice(0, 10) !== date)) {
    throw new Error('A valid shortfall date is required.');
  }
  const dateLabel = date ? new Date(`${date}T12:00:00Z`).toLocaleDateString('en-GB', {
    day: 'numeric', month: 'long', year: 'numeric', timeZone: 'Europe/London',
  }) : 'the next 30 days';
  const causes = Array.isArray(forecast.causes)
    ? forecast.causes.filter((cause) => typeof cause === 'string').slice(0, 5).map((cause) => cause.slice(0, 180)) : [];
  const note = typeof input.note === 'string' ? input.note.trim().slice(0, 1000) : '';
  const hasShortfall = forecast.shortfallPence > 0;
  const situation = hardship === 'income_drop' ? 'a change in my income'
    : hardship === 'unexpected_bill' ? 'an unexpected bill' : 'a concern about my account';
  const pressure = hasShortfall ? `an estimated ${money(forecast.shortfallPence)} cash-flow gap on ${dateLabel}`
    : 'pressure on my budget, although my current forecast stays above zero';
  const sources = [
    {
      title: 'MoneyHelper · Help if you’re struggling to pay your bills',
      url: 'https://www.moneyhelper.org.uk/en/everyday-money/credit/struggling-to-pay-your-gas-or-electricity-bill',
      excerpt: 'Speak with the organisation you owe before a payment is missed. Review essential bills and ask what affordable support is available.',
      reviewedAt: '2026-11-07',
    },
    {
      title: 'FCA · Support when money is tight',
      url: 'https://www.fca.org.uk/consumers/financial-impact-rising-costs-living',
      excerpt: 'Contact your provider early. Support depends on your circumstances; ask how a proposed arrangement would affect your credit file.',
      reviewedAt: '2026-11-07',
    },
    {
      title: 'NatWest · Help with money worries',
      url: 'https://www.natwest.com/support-centre/payments/general/im-struggling-with-my-bills-how-can-you-help.html',
      excerpt: 'NatWest offers a conversation about financial concerns and available support. Use its official support page to contact the bank.',
      reviewedAt: '2026-11-07',
    },
  ];
  const steps = [
    {
      id: 'protect-essentials', title: 'Protect the essentials first',
      detail: `Your planned essential costs over the next 30 days are ${money(profile.monthlyEssentialsPence)}. Check rent or mortgage, energy, Council Tax and food before deciding what is affordable. If essentials are at risk, use MoneyHelper’s free debt-advice finder.`,
    },
    {
      id: 'check-budget', title: 'Check the dates and amounts',
      detail: hasShortfall
        ? `The forecast suggests a ${money(forecast.shortfallPence)} gap on ${dateLabel}. Confirm expected income and bill dates. ${causes.length ? `The main pressures are ${causes.join('; ')}.` : 'Some future entries are estimates.'}`
        : 'Your forecast remains above zero. Check your next income date, upcoming bills and any missing spending before requesting a change.',
    },
    {
      id: 'ask-support', title: hardship === 'complaint' ? 'Explain your concern in writing' : 'Ask about support before the payment',
      detail: hardship === 'complaint'
        ? 'Review the draft, add account details and explain what happened and the resolution you want. Send it through the provider’s official complaints channel and keep a copy.'
        : 'Review the request below and contact the relevant provider through its official channel. Ask which affordable options exist and how they could affect interest, charges and your credit file. Do not stop or change payments without discussing the consequences.',
    },
    {
      id: 'follow-up', title: 'Keep a record and check back',
      detail: 'Save the reply and any agreed dates. If your income or bills change, update the forecast. Support, fee changes and payment arrangements require the provider’s agreement; this draft makes no eligibility promise.',
    },
  ];
  const subject = hardship === 'complaint' ? 'Complaint: please review my account concern'
    : 'Request for support with an upcoming payment';
  const body = hardship === 'complaint'
    ? `Dear Customer Support Team,\n\nI am writing to raise a complaint about [describe the product, date and what happened].\n\nMy current budget shows ${pressure}. My expected income over the next 30 days is ${money(profile.monthlyIncomePence)} and my planned essential costs over the next 30 days are ${money(profile.monthlyEssentialsPence)}. These figures come from a demo forecast and must be checked before this letter is used.\n\n${note ? `My description of the issue: ${note}\n\n` : ''}Please investigate [explain the issue and attach relevant evidence]. The outcome I would like is [state the resolution requested]. Please confirm the next steps and how you will keep me updated.\n\nMy account/reference: [add securely]\nPreferred contact method: [add]\n\nYours faithfully,\n${name}`
    : `Dear Financial Support Team,\n\nI would like to discuss support before I miss a payment. I am experiencing ${situation}, and my current budget shows ${pressure}.\n\nMy expected income over the next 30 days is ${money(profile.monthlyIncomePence)} and my planned essential costs over the next 30 days are ${money(profile.monthlyEssentialsPence)}. My current account balance is ${money(profile.openingBalancePence)}. These figures come from a demo forecast and must be checked before this letter is used.\n\n${note ? `Additional information I would like you to consider: ${note}\n\n` : ''}Please help me review affordable options, including whether the payment date or amount can be adjusted. Please explain any effect on interest, fees, my credit file and future payments before I agree to a change. I am not asking to cancel a payment without discussing the consequences.\n\nI can provide a checked income-and-expenditure summary and relevant statements. Please let me know what else you need and confirm any agreed arrangement in writing.\n\nMy account/reference: [add securely]\nPreferred contact method: [add]\n\nKind regards,\n${name}`;
  return {
    mode: 'live_n8n',
    workflow: { name: 'Second Chance · Personal recovery plan', executionId: String(executionId), executedAt, engine: 'n8n' },
    title: hardship === 'complaint' ? 'A clear way to raise your concern' : 'A little breathing room, one step at a time',
    summary: hasShortfall ? `Let’s plan around the estimated ${money(forecast.shortfallPence)} gap on ${dateLabel}. Start with the essentials, then ask for support.`
      : 'Your current forecast stays above zero. You can still ask for support early, explain your circumstances and review any options before agreeing.',
    steps,
    draft: { subject, recipient: hardship === 'complaint' ? 'Your provider’s complaints team' : 'Your bank or bill provider’s financial support team', body },
    evidence: ['Checked income and expenditure summary', 'Recent statements or payslips showing the income change', 'The bill or payment notice, including its date and reference', 'Any relevant messages from the provider'],
    knownFacts: [
      `Synthetic profile: ${name}.`,
      `Demo current account balance: ${money(profile.openingBalancePence)}.`,
      `Expected income over the next 30 days: ${money(profile.monthlyIncomePence)}; planned essential costs over the next 30 days: ${money(profile.monthlyEssentialsPence)}.`,
      hasShortfall ? `Calculated forecast gap: ${money(forecast.shortfallPence)} on ${dateLabel}.` : 'The supplied forecast reports no shortfall.',
      ...(note ? ['The extra note is user-provided and has not been independently verified.'] : []),
    ],
    assumptions: [
      'All customer figures are synthetic demo data; future income, spending and payment dates may change.',
      'The forecast is a scenario estimate, not a bank balance guarantee or a credit decision.',
      'A provider has not agreed to a change, waived fees or confirmed eligibility.',
      'This is a rules-based personalised draft from n8n, not regulated debt advice or a submitted request.',
    ],
    sources,
  };
}

const request = $input.first().json;
return [{ json: createRecoveryPlan(request.body ?? request, $execution.id, new Date().toISOString()) }];
