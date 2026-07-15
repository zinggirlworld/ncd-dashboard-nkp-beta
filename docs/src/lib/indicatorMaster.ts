export type IndicatorMaster = {
	indicator_no: number;
	indicator_name: string;
	target_text: string;
	target_type: string;
	target_value: number;
	category: string;
};

export const indicatorMaster: IndicatorMaster[] = [
	{
		indicator_no: 1,
		indicator_name: 'อัตราผู้ป่วย DM ที่ได้รับการตรวจ HbA1c',
		target_text: '>= 70%',
		target_type: '>=',
		target_value: 70,
		category: 'ควบคุมน้ำตาล'
	},
	{
		indicator_no: 2,
		indicator_name: 'อัตราผู้ป่วยเบาหวานชนิดที่ 2 ที่มีระดับ HbA1c < 7%',
		target_text: '> 40%',
		target_type: '>',
		target_value: 40,
		category: 'ควบคุมน้ำตาล'
	},
	{
		indicator_no: 3,
		indicator_name: 'อัตราผู้ป่วยเบาหวานชนิดที่ 1 ที่มีระดับ HbA1c < 7%',
		target_text: '> 40%',
		target_type: '>',
		target_value: 40,
		category: 'ควบคุมน้ำตาล'
	},
	{
		indicator_no: 4,
		indicator_name: 'อัตราการรักษาในโรงพยาบาลเนื่องจากภาวะแทรกซ้อนเฉียบพลันจาก DM',
		target_text: '< 4%',
		target_type: '<',
		target_value: 4,
		category: 'ภาวะแทรกซ้อนเฉียบพลัน'
	},
	{
		indicator_no: 5,
		indicator_name: 'อัตราการรักษาในโรงพยาบาลเนื่องจากภาวะแทรกซ้อนเฉียบพลัน Hypoglycemia',
		target_text: '< 4%',
		target_type: '<',
		target_value: 4,
		category: 'ภาวะแทรกซ้อนเฉียบพลัน'
	},
	{
		indicator_no: 6,
		indicator_name: 'อัตราการรักษาในโรงพยาบาลเนื่องจาก Hyperglycemia / DKA',
		target_text: '< 4%',
		target_type: '<',
		target_value: 4,
		category: 'ภาวะแทรกซ้อนเฉียบพลัน'
	},
	{
		indicator_no: 7,
		indicator_name: 'อัตราผู้ป่วย DM ที่ได้รับการตรวจ Lipid profile',
		target_text: '> 70%',
		target_type: '>',
		target_value: 70,
		category: 'Lipid / BP / ยา'
	},
	{
		indicator_no: 8,
		indicator_name: 'อัตราผู้ป่วย DM ที่มีระดับ LDL < 100 mg/dL',
		target_text: '> 60%',
		target_type: '>',
		target_value: 60,
		category: 'Lipid / BP / ยา'
	},
	{
		indicator_no: 9,
		indicator_name: 'อัตราของระดับความดันโลหิตในผู้ป่วย DM <= 130/80 mmHg',
		target_text: '>= 60%',
		target_type: '>=',
		target_value: 60,
		category: 'Lipid / BP / ยา'
	},
	{
		indicator_no: 10,
		indicator_name: 'อัตราผู้ป่วย DM อายุ 40 ปีขึ้นไปที่ได้รับยา Aspirin',
		target_text: '> 70%',
		target_type: '>',
		target_value: 70,
		category: 'Lipid / BP / ยา'
	},
	{
		indicator_no: 11,
		indicator_name: 'อัตราผู้ป่วย DM ที่ได้รับการตรวจ Microalbuminuria ประจำปี',
		target_text: '> 80%',
		target_type: '>',
		target_value: 80,
		category: 'ไต'
	},
	{
		indicator_no: 12,
		indicator_name: 'อัตราผู้ป่วย DM มี Microalbuminuria ที่ได้รับยา ACEI หรือ ARB',
		target_text: '>= 60%',
		target_type: '>=',
		target_value: 60,
		category: 'ไต'
	},
	{
		indicator_no: 13,
		indicator_name: 'อัตราผู้ป่วย DM ที่ได้รับการตรวจจอประสาทตาประจำปี',
		target_text: '>= 70%',
		target_type: '>=',
		target_value: 70,
		category: 'ตา / ฟัน / เท้า'
	},
	{
		indicator_no: 14,
		indicator_name: 'อัตราผู้ป่วย DM ที่ได้รับการตรวจสุขภาพช่องปากประจำปี',
		target_text: '> 40%',
		target_type: '>',
		target_value: 40,
		category: 'ตา / ฟัน / เท้า'
	},
	{
		indicator_no: 15,
		indicator_name: 'อัตราผู้ป่วย DM ที่ได้รับการตรวจเท้าอย่างละเอียดประจำปี',
		target_text: '>= 80%',
		target_type: '>=',
		target_value: 80,
		category: 'ตา / ฟัน / เท้า'
	},
	{
		indicator_no: 16,
		indicator_name: 'อัตราผู้ป่วยเบาหวานที่มี Diabetic retinopathy',
		target_text: '< 15%',
		target_type: '<',
		target_value: 15,
		category: 'ภาวะแทรกซ้อนเรื้อรัง'
	},
	{
		indicator_no: 17,
		indicator_name: 'อัตราผู้ป่วยเบาหวานที่มี Diabetic nephropathy',
		target_text: '< 30%',
		target_type: '<',
		target_value: 30,
		category: 'ภาวะแทรกซ้อนเรื้อรัง'
	},
	{
		indicator_no: 18,
		indicator_name: 'อัตราผู้ป่วยเบาหวานที่มีแผลที่เท้า',
		target_text: '< 5%',
		target_type: '<',
		target_value: 5,
		category: 'ภาวะแทรกซ้อนเรื้อรัง'
	}
];
