import jsPDF from 'jspdf';
import autoTable from 'jspdf-autotable';
import { format } from 'date-fns';
import { fr } from 'date-fns/locale';

// Extend jsPDF type to include autoTable
declare module 'jspdf' {
  interface jsPDF {
    lastAutoTable: { finalY: number };
  }
}

interface CompanyInfo {
  name: string;
  address?: string;
  phone?: string;
  email?: string;
}

const COMPANY_INFO: CompanyInfo = {
  name: 'KIMBO Procurement Management',
  address: 'Douala, Cameroun',
  phone: '+237 XXX XXX XXX',
  email: 'contact@kimbo.cm',
};

// Colors based on the design system
const COLORS = {
  primary: [232, 147, 45] as [number, number, number],      // Orange KIMBO
  secondary: [89, 53, 31] as [number, number, number],      // Marron profond
  text: [30, 30, 30] as [number, number, number],
  muted: [120, 120, 120] as [number, number, number],
  success: [34, 139, 34] as [number, number, number],
  warning: [200, 130, 50] as [number, number, number],
  danger: [180, 60, 60] as [number, number, number],
};

const formatMontant = (value: number | null, currency?: string) => {
  if (!value) return '0 XAF';
  return new Intl.NumberFormat('fr-FR', {
    style: 'decimal',
    minimumFractionDigits: 0,
    maximumFractionDigits: 0,
  }).format(value) + ' ' + (currency || 'XAF');
};

const addHeader = (doc: jsPDF, title: string, reference: string) => {
  const pageWidth = doc.internal.pageSize.getWidth();
  
  // Logo/Company name
  doc.setFontSize(20);
  doc.setTextColor(...COLORS.primary);
  doc.setFont('helvetica', 'bold');
  doc.text(COMPANY_INFO.name, 14, 20);
  
  // Company info
  doc.setFontSize(9);
  doc.setTextColor(...COLORS.muted);
  doc.setFont('helvetica', 'normal');
  doc.text(COMPANY_INFO.address || '', 14, 26);
  
  // Document title
  doc.setFontSize(16);
  doc.setTextColor(...COLORS.secondary);
  doc.setFont('helvetica', 'bold');
  doc.text(title, pageWidth - 14, 20, { align: 'right' });
  
  // Reference
  doc.setFontSize(11);
  doc.setTextColor(...COLORS.text);
  doc.setFont('helvetica', 'normal');
  doc.text(reference, pageWidth - 14, 28, { align: 'right' });
  
  // Date
  doc.setFontSize(9);
  doc.setTextColor(...COLORS.muted);
  doc.text(`Généré le ${format(new Date(), 'dd MMMM yyyy à HH:mm', { locale: fr })}`, pageWidth - 14, 34, { align: 'right' });
  
  // Separator line
  doc.setDrawColor(...COLORS.primary);
  doc.setLineWidth(0.5);
  doc.line(14, 40, pageWidth - 14, 40);
  
  return 45; // Return Y position after header
};

const addFooter = (doc: jsPDF) => {
  const pageHeight = doc.internal.pageSize.getHeight();
  const pageWidth = doc.internal.pageSize.getWidth();
  const pageCount = doc.getNumberOfPages();
  
  for (let i = 1; i <= pageCount; i++) {
    doc.setPage(i);
    
    // Footer line
    doc.setDrawColor(...COLORS.muted);
    doc.setLineWidth(0.3);
    doc.line(14, pageHeight - 20, pageWidth - 14, pageHeight - 20);
    
    // Footer text
    doc.setFontSize(8);
    doc.setTextColor(...COLORS.muted);
    doc.text(COMPANY_INFO.name, 14, pageHeight - 14);
    doc.text(`Page ${i} / ${pageCount}`, pageWidth - 14, pageHeight - 14, { align: 'right' });
  }
};

const addInfoBlock = (
  doc: jsPDF, 
  startY: number, 
  title: string, 
  data: Array<{ label: string; value: string }>
) => {
  doc.setFontSize(11);
  doc.setTextColor(...COLORS.secondary);
  doc.setFont('helvetica', 'bold');
  doc.text(title, 14, startY);
  
  let y = startY + 6;
  doc.setFontSize(9);
  doc.setFont('helvetica', 'normal');
  
  data.forEach(item => {
    doc.setTextColor(...COLORS.muted);
    doc.text(`${item.label}:`, 14, y);
    doc.setTextColor(...COLORS.text);
    doc.text(item.value, 50, y);
    y += 5;
  });
  
  return y + 5;
};

// ===================== DEMANDE D'ACHAT =====================
interface DAExportData {
  reference: string;
  status: string;
  department: string;
  category: string;
  priority: string;
  description: string;
  createdAt: string;
  createdBy: string;
  totalAmount: number | null;
  currency: string;
  fournisseur?: string;
  articles: Array<{
    designation: string;
    quantity: number;
    unit: string;
    unitPrice?: number;
    total?: number;
  }>;
}

export const exportDAToPDF = (data: DAExportData) => {
  const doc = new jsPDF();
  
  let y = addHeader(doc, "DEMANDE D'ACHAT", data.reference);
  
  // Status badge
  doc.setFontSize(10);
  doc.setTextColor(...COLORS.primary);
  doc.setFont('helvetica', 'bold');
  doc.text(`Statut: ${data.status}`, 14, y);
  y += 10;
  
  // Info blocks
  y = addInfoBlock(doc, y, 'Informations générales', [
    { label: 'Département', value: data.department },
    { label: 'Catégorie', value: data.category },
    { label: 'Priorité', value: data.priority },
    { label: 'Créé le', value: data.createdAt },
    { label: 'Créé par', value: data.createdBy },
  ]);
  
  if (data.fournisseur) {
    y = addInfoBlock(doc, y, 'Fournisseur sélectionné', [
      { label: 'Nom', value: data.fournisseur },
    ]);
  }
  
  // Description
  doc.setFontSize(11);
  doc.setTextColor(...COLORS.secondary);
  doc.setFont('helvetica', 'bold');
  doc.text('Description', 14, y);
  y += 6;
  
  doc.setFontSize(9);
  doc.setTextColor(...COLORS.text);
  doc.setFont('helvetica', 'normal');
  const splitDescription = doc.splitTextToSize(data.description, 180);
  doc.text(splitDescription, 14, y);
  y += splitDescription.length * 5 + 10;
  
  // Articles table
  doc.setFontSize(11);
  doc.setTextColor(...COLORS.secondary);
  doc.setFont('helvetica', 'bold');
  doc.text('Articles', 14, y);
  y += 4;
  
  const tableData = data.articles.map(art => [
    art.designation,
    art.quantity.toString(),
    art.unit,
    art.unitPrice ? formatMontant(art.unitPrice) : '-',
    art.total ? formatMontant(art.total) : '-',
  ]);
  
  autoTable(doc, {
    startY: y,
    head: [['Désignation', 'Qté', 'Unité', 'P.U.', 'Total']],
    body: tableData,
    theme: 'striped',
    headStyles: {
      fillColor: COLORS.secondary,
      textColor: [255, 255, 255],
      fontStyle: 'bold',
      fontSize: 9,
    },
    bodyStyles: {
      fontSize: 9,
      textColor: COLORS.text,
    },
    columnStyles: {
      0: { cellWidth: 80 },
      1: { cellWidth: 20, halign: 'center' },
      2: { cellWidth: 25, halign: 'center' },
      3: { cellWidth: 30, halign: 'right' },
      4: { cellWidth: 30, halign: 'right' },
    },
    margin: { left: 14, right: 14 },
  });
  
  // Total
  if (data.totalAmount) {
    const finalY = doc.lastAutoTable.finalY + 10;
    doc.setFontSize(12);
    doc.setTextColor(...COLORS.secondary);
    doc.setFont('helvetica', 'bold');
    doc.text('TOTAL:', 140, finalY, { align: 'right' });
    doc.setTextColor(...COLORS.primary);
    doc.text(formatMontant(data.totalAmount, data.currency), 180, finalY, { align: 'right' });
  }
  
  addFooter(doc);
  doc.save(`DA_${data.reference}.pdf`);
};

// ===================== BON DE LIVRAISON =====================
interface BLExportData {
  reference: string;
  status: string;
  department: string;
  warehouse?: string;
  blType: string;
  deliveryDate?: string;
  createdAt: string;
  createdBy: string;
  besoinTitle: string;
  observations?: string;
  articles: Array<{
    designation: string;
    quantityOrdered: number;
    quantityDelivered: number;
    unit: string;
    ecartReason?: string;
  }>;
}

export const exportBLToPDF = (data: BLExportData) => {
  const doc = new jsPDF();
  
  let y = addHeader(doc, 'BON DE LIVRAISON', data.reference);
  
  // Status badge
  doc.setFontSize(10);
  doc.setTextColor(...COLORS.primary);
  doc.setFont('helvetica', 'bold');
  doc.text(`Statut: ${data.status}`, 14, y);
  y += 10;
  
  // Info blocks
  y = addInfoBlock(doc, y, 'Informations générales', [
    { label: 'Département', value: data.department },
    { label: 'Type', value: data.blType },
    { label: 'Magasin', value: data.warehouse || 'Non spécifié' },
    { label: 'Date livraison', value: data.deliveryDate || 'Non définie' },
    { label: 'Créé le', value: data.createdAt },
    { label: 'Créé par', value: data.createdBy },
  ]);
  
  y = addInfoBlock(doc, y, 'Besoin associé', [
    { label: 'Titre', value: data.besoinTitle },
  ]);
  
  if (data.observations) {
    doc.setFontSize(11);
    doc.setTextColor(...COLORS.secondary);
    doc.setFont('helvetica', 'bold');
    doc.text('Observations', 14, y);
    y += 6;
    
    doc.setFontSize(9);
    doc.setTextColor(...COLORS.text);
    doc.setFont('helvetica', 'normal');
    const splitObs = doc.splitTextToSize(data.observations, 180);
    doc.text(splitObs, 14, y);
    y += splitObs.length * 5 + 10;
  }
  
  // Articles table
  doc.setFontSize(11);
  doc.setTextColor(...COLORS.secondary);
  doc.setFont('helvetica', 'bold');
  doc.text('Articles', 14, y);
  y += 4;
  
  const tableData = data.articles.map(art => {
    const ecart = art.quantityOrdered - art.quantityDelivered;
    return [
      art.designation,
      art.quantityOrdered.toString(),
      art.quantityDelivered.toString(),
      ecart > 0 ? `-${ecart}` : '0',
      art.unit,
      art.ecartReason || '-',
    ];
  });
  
  autoTable(doc, {
    startY: y,
    head: [['Désignation', 'Commandé', 'Livré', 'Écart', 'Unité', 'Motif écart']],
    body: tableData,
    theme: 'striped',
    headStyles: {
      fillColor: COLORS.secondary,
      textColor: [255, 255, 255],
      fontStyle: 'bold',
      fontSize: 9,
    },
    bodyStyles: {
      fontSize: 9,
      textColor: COLORS.text,
    },
    columnStyles: {
      0: { cellWidth: 50 },
      1: { cellWidth: 22, halign: 'center' },
      2: { cellWidth: 22, halign: 'center' },
      3: { cellWidth: 20, halign: 'center' },
      4: { cellWidth: 20, halign: 'center' },
      5: { cellWidth: 48 },
    },
    margin: { left: 14, right: 14 },
  });
  
  addFooter(doc);
  doc.save(`BL_${data.reference}.pdf`);
};

// ===================== ÉCRITURE COMPTABLE =====================
interface EcritureExportData {
  reference: string;
  daReference: string;
  libelle: string;
  dateEcriture: string;
  classesSyscohada: number;
  compteComptable: string;
  natureCharge: string;
  centreCout?: string;
  debit: number;
  credit: number;
  devise: string;
  modePaiement?: string;
  referencePaiement?: string;
  isValidated: boolean;
  validatedAt?: string;
  validatedBy?: string;
  createdAt: string;
  createdBy: string;
  observations?: string;
}

export const exportEcritureToPDF = (data: EcritureExportData) => {
  const doc = new jsPDF();
  
  let y = addHeader(doc, 'ÉCRITURE COMPTABLE', data.reference);
  
  // Status
  doc.setFontSize(10);
  doc.setTextColor(...(data.isValidated ? COLORS.success : COLORS.warning));
  doc.setFont('helvetica', 'bold');
  doc.text(`Statut: ${data.isValidated ? 'Validée' : 'En attente de validation'}`, 14, y);
  y += 10;
  
  // Info blocks
  y = addInfoBlock(doc, y, 'Informations générales', [
    { label: 'DA associée', value: data.daReference },
    { label: 'Libellé', value: data.libelle },
    { label: 'Date écriture', value: data.dateEcriture },
    { label: 'Créé le', value: data.createdAt },
    { label: 'Créé par', value: data.createdBy },
  ]);
  
  y = addInfoBlock(doc, y, 'Classification SYSCOHADA', [
    { label: 'Classe', value: `Classe ${data.classesSyscohada}` },
    { label: 'Compte', value: data.compteComptable },
    { label: 'Nature charge', value: data.natureCharge },
    { label: 'Centre de coût', value: data.centreCout || 'Non spécifié' },
  ]);
  
  // Montants table
  doc.setFontSize(11);
  doc.setTextColor(...COLORS.secondary);
  doc.setFont('helvetica', 'bold');
  doc.text('Montants', 14, y);
  y += 4;
  
  autoTable(doc, {
    startY: y,
    head: [['Débit', 'Crédit', 'Devise']],
    body: [[
      formatMontant(data.debit, data.devise),
      formatMontant(data.credit, data.devise),
      data.devise,
    ]],
    theme: 'striped',
    headStyles: {
      fillColor: COLORS.secondary,
      textColor: [255, 255, 255],
      fontStyle: 'bold',
      fontSize: 10,
    },
    bodyStyles: {
      fontSize: 10,
      textColor: COLORS.text,
      fontStyle: 'bold',
    },
    columnStyles: {
      0: { halign: 'center' },
      1: { halign: 'center' },
      2: { halign: 'center' },
    },
    margin: { left: 14, right: 14 },
  });
  
  y = doc.lastAutoTable.finalY + 10;
  
  if (data.modePaiement) {
    y = addInfoBlock(doc, y, 'Informations de paiement', [
      { label: 'Mode', value: data.modePaiement },
      { label: 'Référence', value: data.referencePaiement || 'Non spécifiée' },
    ]);
  }
  
  if (data.isValidated && data.validatedAt) {
    y = addInfoBlock(doc, y, 'Validation', [
      { label: 'Validé le', value: data.validatedAt },
      { label: 'Validé par', value: data.validatedBy || 'N/A' },
    ]);
  }
  
  if (data.observations) {
    doc.setFontSize(11);
    doc.setTextColor(...COLORS.secondary);
    doc.setFont('helvetica', 'bold');
    doc.text('Observations', 14, y);
    y += 6;
    
    doc.setFontSize(9);
    doc.setTextColor(...COLORS.text);
    doc.setFont('helvetica', 'normal');
    const splitObs = doc.splitTextToSize(data.observations, 180);
    doc.text(splitObs, 14, y);
  }
  
  addFooter(doc);
  doc.save(`ECRITURE_${data.reference}.pdf`);
};
